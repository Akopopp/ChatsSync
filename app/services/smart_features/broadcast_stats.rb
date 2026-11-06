# Smart features > "Broadcast tools": what happened after a WhatsApp broadcast. Who got it, delivered, read and
# replied (within 3 days), and the orders the people who got it placed within 7 days. Kept in Redis for 90 days.
module SmartFeatures::BroadcastStats
  SET_KEY = 'chatssync:broadcast:%<id>s:%<kind>s'.freeze
  MESSAGE_KEY = 'chatssync:broadcast_message:%<wamid>s'.freeze
  CONTACT_KEY = 'chatssync:broadcast_contact:%<id>s'.freeze
  KINDS = %w[recipients delivered read failed replied].freeze
  KEEP = 90.days
  REPLY_WINDOW = 3.days
  ORDER_WINDOW = 7.days

  module_function

  # message_id is Meta's id of a template message; free text sent inside the 24-hour window has none yet.
  def sent(campaign, contact, message_id)
    Redis::Alfred.pipelined do |redis|
      add(redis, campaign.id, 'recipients', contact.id)
      redis.set(format(MESSAGE_KEY, wamid: message_id), campaign.id, ex: ORDER_WINDOW.to_i) if message_id.present?
      redis.set(format(CONTACT_KEY, id: contact.id), campaign.id, ex: REPLY_WINDOW.to_i)
    end
  end

  # A delivery status from Meta. Read also counts as delivered.
  def status(message_id, status, campaign_id = nil)
    return unless %w[delivered read failed].include?(status.to_s)

    campaign_id ||= Redis::Alfred.get(format(MESSAGE_KEY, wamid: message_id))
    return if campaign_id.blank?

    kinds = status.to_s == 'read' ? %w[delivered read] : [status.to_s]
    Redis::Alfred.pipelined { |redis| kinds.each { |kind| add(redis, campaign_id, kind, message_id) } }
  end

  def reply(message)
    campaign_id = Redis::Alfred.get(format(CONTACT_KEY, id: message.sender_id))
    Redis::Alfred.pipelined { |redis| add(redis, campaign_id, 'replied', message.sender_id) } if campaign_id.present?
  end

  def summary(campaign)
    counts = Redis::Alfred.pipelined { |redis| KINDS.each { |kind| redis.scard(key(campaign.id, kind)) } }
    return if counts.first.to_i.zero?

    since = campaign.scheduled_at || campaign.created_at
    ids = Redis::Alfred.with { |redis| redis.smembers(key(campaign.id, 'recipients')) }
    orders = campaign.account.orders.where(contact_id: ids, created_at: since..(since + ORDER_WINDOW)).where.not(status: 'cancelled')
    KINDS.zip(counts).to_h.transform_keys { |kind| kind == 'recipients' ? 'sent' : kind }
         .merge('orders' => orders.count, 'sales' => orders.sum(:total).to_s)
  end

  def add(redis, campaign_id, kind, member)
    redis.sadd(key(campaign_id, kind), member.to_s)
    redis.expire(key(campaign_id, kind), KEEP.to_i)
  end

  def key(campaign_id, kind)
    format(SET_KEY, id: campaign_id, kind: kind)
  end
end
