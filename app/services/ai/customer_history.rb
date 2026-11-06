# What the business already knows about a returning customer, for the AI prompt
# (Settings > Smart features > "Remember returning customers").
class Ai::CustomerHistory
  pattr_initialize [:conversation!]

  LIMIT = 3

  def prompt_text
    contact = conversation.contact
    return if contact.nil?

    lines = [earlier_chats(contact), past_orders(contact), past_appointments(contact)].compact
    return if lines.empty?

    <<~TEXT.strip
      About this customer (they have contacted the business before):
      #{lines.map { |line| "- #{line}" }.join("\n")}
      Welcome them back once in a natural way, and use this only when it helps the reply. Never read the list out.
    TEXT
  end

  private

  def account
    conversation.account
  end

  def earlier_chats(contact)
    count = account.conversations.where(contact_id: contact.id).where.not(id: conversation.id).count
    "#{count} earlier #{'chat'.pluralize(count)}" if count.positive?
  end

  def past_orders(contact)
    orders = account.orders.where(contact_id: contact.id).where.not(status: 'cancelled').order(created_at: :desc).limit(LIMIT)
    return if orders.empty?

    text = orders.map { |order| "#{order.created_at.to_date.to_fs(:long)}: #{order_items(order)} (#{order.status})" }.join('; ')
    "Past orders: #{text}"
  end

  def order_items(order)
    Array(order.items).map { |item| "#{item['name']} x#{item['quantity']}" }.join(', ').presence || 'order'
  end

  def past_appointments(contact)
    appointments = account.appointments.where(contact_id: contact.id).where(status: %w[done booked]).order(starts_at: :desc).limit(LIMIT)
    return if appointments.empty?

    text = appointments.map { |item| "#{item.starts_at.to_date.to_fs(:long)} #{item.service.presence || 'appointment'} (#{item.status})" }
    "Appointments: #{text.join('; ')}"
  end
end
