# Smart features > "Broadcast tools": who a WhatsApp broadcast goes to, and about how much Meta charges for it.
# Besides labels, a broadcast can go to everyone who messaged the number, customers from ads in the last 30 days,
# or customers who ordered or booked. Customers who sent STOP never get broadcasts.
module SmartFeatures::BroadcastAudience
  SEGMENTS = %w[all_contacts ad_leads buyers].freeze
  AD_DAYS = 30
  # Meta's per-message rates for Pakistan (USD, October 2026); change them with env vars when Meta does.
  RATES_USD = {
    'MARKETING' => ENV.fetch('WHATSAPP_RATE_MARKETING_USD', '0.0473').to_f,
    'UTILITY' => ENV.fetch('WHATSAPP_RATE_UTILITY_USD', '0.015').to_f,
    'AUTHENTICATION' => ENV.fetch('WHATSAPP_RATE_AUTHENTICATION_USD', '0.015').to_f
  }.freeze

  module_function

  def contacts(account, inbox, labels, segments)
    ids = labels.any? ? account.contacts.tagged_with(labels, any: true).pluck(:id) : []
    segments = [] unless account.smart_feature_on?(:broadcast_tools)
    segments.each { |segment| ids |= segment_contact_ids(account, inbox, segment) }
    account.contacts.where(id: ids).where.not(phone_number: [nil, '']).tagged_with(Whatsapp::StopOptOut::LABEL, exclude: true)
  end

  def for_campaign(campaign, labels)
    segments = Array(campaign.audience).select { |item| item['type'] == 'Segment' }.pluck('id') & SEGMENTS
    contacts(campaign.account, campaign.inbox, labels, segments)
  end

  def segment_contact_ids(account, inbox, segment)
    case segment
    when 'all_contacts' then inbox.contact_inboxes.distinct.pluck(:contact_id)
    when 'ad_leads'
      inbox.conversations.where("conversations.additional_attributes ->> 'cs_ad_lead' = 'true'")
           .where("(conversations.additional_attributes ->> 'cs_ad_lead_at')::bigint > ?", AD_DAYS.days.ago.to_i).distinct.pluck(:contact_id)
    when 'buyers'
      account.orders.where.not(status: 'cancelled').distinct.pluck(:contact_id) |
        account.appointments.where.not(status: 'cancelled').distinct.pluck(:contact_id)
    else []
    end.compact
  end

  # About how many customers get it and what Meta charges, in PKR.
  def estimate(account, inbox, labels, segments, category)
    count = inbox ? contacts(account, inbox, labels, segments).count : 0
    rate = RATES_USD.fetch(category.to_s.upcase, RATES_USD['MARKETING']) * ENV.fetch('USD_PKR_RATE', '280').to_f
    { enabled: true, contacts: count, rate: rate.round(2), cost: (rate * count).round, currency: 'PKR' }
  end
end
