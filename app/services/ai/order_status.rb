# Lets the AI agent answer "where is my order?": it gets this customer's latest orders
# (from the AI, the team or the online store) with their status and tracking notes.
class Ai::OrderStatus
  MAX_ORDERS = 3

  pattr_initialize [:account!, :conversation]

  def self.enabled_for?(account)
    account.orders.exists?
  end

  def prompt_text(_question)
    return '' if orders.empty?

    setting = account.catalog_setting || CatalogSetting.new
    lines = orders.map do |order|
      items = order.items.map { |item| "#{item['name']} x#{item['quantity']}" }.join(', ')
      ["Order ##{order.number}", order.external_ref, order.created_at.to_date.to_fs(:long), items, setting.money(order.total),
       "status: #{order.status}", order.notes.to_s.squish.truncate(200).presence].compact_blank.join(' | ')
    end
    <<~TEXT
      This customer's latest orders:
      #{lines.join("\n")}
      - If the customer asks about their order, answer from these orders: status, items, total and any tracking in the notes.
      - Never make up a delivery date or tracking number. If they need more than this, reply with #{Ai::PromptBuilder::HANDOFF_TAG}.
    TEXT
  end

  def apply(reply, roman_urdu:) # rubocop:disable Lint/UnusedMethodArgument
    reply
  end

  private

  def orders
    @orders ||= begin
      contact = conversation&.contact
      if contact.nil?
        []
      else
        phones = [contact.phone_number].compact_blank
        account.orders.where(contact_id: contact.id).or(account.orders.where(customer_phone: phones)).order(created_at: :desc).limit(MAX_ORDERS).to_a
      end
    end
  end
end
