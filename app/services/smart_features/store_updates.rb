# Smart features > Online store: WhatsApp messages from store events sent to the store link.
# - "Shipping updates": when an order is shipped, the customer gets the chosen template with the courier
#   and tracking. Variables: customer name, order number, courier, tracking number, tracking link.
# - "Abandoned cart reminder": a Shopify checkout that is not finished within the chosen hours gets the
#   chosen template once. Variables: customer name, items, total, checkout link.
class SmartFeatures::StoreUpdates
  CART_KEY = 'cs:cart:%<account>s:%<token>s'.freeze
  ORDERED_KEY = 'cs:cart_ordered:%<account>s:%<phone>s'.freeze
  SENT_KEY = 'cs:store_sent:%<account>s:%<key>s'.freeze
  KEEP = 3.days

  pattr_initialize [:account!]

  # What the settings page needs for "ship" or "cart": the WhatsApp numbers and the templates of the chosen one.
  def self.settings_for(account, prefix)
    inboxes = Whatsapp::NumberHealth.cloud_inboxes(account)
    inbox = inboxes.find { |item| item.id == account.smart_feature("#{prefix}_inbox_id") }
    { url: "#{ENV.fetch('FRONTEND_URL', '')}/webhooks/store_orders/#{account.smart_feature(:cod_token)}",
      inboxes: inboxes.map { |item| { id: item.id, name: item.name } },
      templates: inbox ? SmartFeatures::TemplateMessage.choices(inbox.channel) : [] }
  end

  def shipped(data)
    sender = sender_for('ship') if account.smart_feature_on?(:ship_updates)
    return if sender.nil?

    phone = SmartFeatures::StoreOrder.phone(data['phone'])
    return if phone.blank? || !first_time?("ship:#{data['ref']}:#{data['tracking_number']}")

    mark_shipped(data)
    sender.deliver(sender.conversation_for(phone, data['name']),
                   [data['name'] || 'Customer', data['ref'].to_s.split.last, data['courier'], data['tracking_number'], data['tracking_url']])
  end

  # Every checkout update is kept; a reminder is checked after the chosen hours.
  def checkout(data)
    phone = SmartFeatures::StoreOrder.phone(data['phone'])
    return if phone.blank? || data['token'].blank?
    return ordered(phone) if data['completed']
    return unless account.smart_feature_on?(:cart_recovery)

    cart = data.merge('phone' => phone, 'at' => Time.current.to_i)
    Redis::Alfred.setex(format(CART_KEY, account: account.id, token: data['token']), cart.to_json, KEEP)
    SmartFeatures::CartReminderJob.set(wait: account.smart_feature(:cart_delay_hours).to_i.hours).perform_later(account.id, data['token'])
  end

  # Any new order from this phone number means the cart was bought.
  def ordered(phone)
    Redis::Alfred.setex(format(ORDERED_KEY, account: account.id, phone: phone), Time.current.to_i, KEEP) if phone.present?
  end

  def remind(token)
    cart = JSON.parse(Redis::Alfred.get(format(CART_KEY, account: account.id, token: token)) || 'null')
    sender = sender_for('cart') if cart && account.smart_feature_on?(:cart_recovery)
    return if sender.nil?
    # A later update moved the reminder; the job made for that update sends it.
    return if Time.current.to_i - cart['at'].to_i < (account.smart_feature(:cart_delay_hours).to_i.hours - 1.minute)
    return if Redis::Alfred.get(format(ORDERED_KEY, account: account.id, phone: cart['phone'])).to_i >= cart['at'].to_i
    return unless first_time?("cart:#{token}")

    items = Array(cart['items']).map { |item| "#{item['name']} x#{item['quantity']}" }.join(', ')
    total = (account.catalog_setting || CatalogSetting.new).money(cart['total'].to_d)
    sender.deliver(sender.conversation_for(cart['phone'], cart['name']), [cart['name'].presence || 'Customer', items, total, cart['url']])
  end

  private

  # The ChatsSync order shows as shipped, with the tracking in its notes (the AI reads it when asked).
  def mark_shipped(data)
    order = account.orders.find_by(external_ref: data['ref'].to_s.truncate(80), status: %w[new confirmed])
    tracking = ['Shipped:', data['courier'], data['tracking_number'], data['tracking_url']].compact_blank.join(' ')
    order&.update!(status: 'shipped', notes: [order.notes, tracking].compact_blank.join("\n").truncate(1000))
  end

  def sender_for(prefix)
    inbox = Whatsapp::NumberHealth.cloud_inboxes(account).find { |item| item.id == account.smart_feature("#{prefix}_inbox_id") }
    template = inbox && SmartFeatures::TemplateMessage.find(inbox.channel, account.smart_feature("#{prefix}_template"),
                                                            account.smart_feature("#{prefix}_template_language"))
    SmartFeatures::TemplateMessage.new(inbox: inbox, template: template) if template
  end

  # Stores send the same event again on retries and order edits; each message goes once.
  def first_time?(key)
    Redis::Alfred.set(format(SENT_KEY, account: account.id, key: key), 1, nx: true, ex: 30.days.to_i)
  end
end
