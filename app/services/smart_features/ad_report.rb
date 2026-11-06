# Smart features > "Ad report": which Click-to-WhatsApp ads brought chats, orders, bookings and sales in the last 30 days.
# The ad of a chat is saved when its first message arrives (Whatsapp::IncomingMessageBaseService#mark_ad_lead).
class SmartFeatures::AdReport
  DAYS = 30
  LIMIT = 25
  FIELDS = %w[cs_ad_id cs_ad_headline cs_ad_url cs_ad_source].freeze

  pattr_initialize [:account!]

  def summary
    ads = rows
    { days: DAYS, ads: ads, chats: ads.sum { |ad| ad[:chats] }, orders: ads.sum { |ad| ad[:orders] },
      bookings: ads.sum { |ad| ad[:bookings] }, sales: ads.sum { |ad| ad[:sales].to_d }.to_s }
  end

  private

  def rows
    chats = ad_chats
    return [] if chats.empty?

    sales = order_totals(chats.keys)
    bookings = account.appointments.where(conversation_id: chats.keys).where.not(status: 'cancelled').group(:conversation_id).count
    chats.group_by { |_id, ad| ad['cs_ad_id'] || ad['cs_ad_headline'] || ad['cs_ad_source'] }
         .map { |_key, list| row(list, sales, bookings) }
         .sort_by { |ad| [-ad[:sales].to_d, -ad[:chats]] }.first(LIMIT)
  end

  # { conversation_id => { 'cs_ad_id' => ..., 'cs_ad_headline' => ..., ... } }
  def ad_chats
    columns = FIELDS.map { |field| Arel.sql("conversations.additional_attributes ->> '#{field}'") }
    account.conversations.where("conversations.additional_attributes ->> 'cs_ad_lead' = 'true'")
           .where("(conversations.additional_attributes ->> 'cs_ad_lead_at')::bigint > ?", DAYS.days.ago.to_i)
           .pluck(:id, *columns).to_h { |id, *values| [id, FIELDS.zip(values).to_h.compact_blank] }
  end

  # { conversation_id => [order count, sales] } for orders that were not cancelled.
  def order_totals(ids)
    account.orders.where(conversation_id: ids).where.not(status: 'cancelled').group(:conversation_id)
           .pluck(:conversation_id, Arel.sql('COUNT(*)'), Arel.sql('SUM(total)')).to_h { |id, count, total| [id, [count, total]] }
  end

  def row(list, sales, bookings)
    ids = list.map(&:first)
    ads = list.map(&:last)
    {
      ad_id: ads.filter_map { |ad| ad['cs_ad_id'] }.first, headline: ads.filter_map { |ad| ad['cs_ad_headline'] }.first,
      url: ads.filter_map { |ad| ad['cs_ad_url'] }.first, source: ads.filter_map { |ad| ad['cs_ad_source'] }.first,
      chats: ids.size, orders: ids.sum { |id| sales.dig(id, 0).to_i }, bookings: ids.sum { |id| bookings[id].to_i },
      sales: ids.sum { |id| sales.dig(id, 1).to_d }.to_s
    }
  end
end
