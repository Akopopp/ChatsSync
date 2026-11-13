# Smart features > "COD order confirmation": a new Shopify or WooCommerce order (sent to the store webhook link)
# becomes an order in ChatsSync, and the customer gets the chosen WhatsApp template with two quick reply buttons.
# The first button confirms the order, the second cancels it; the order status and a label change on its own.
class SmartFeatures::CodConfirmation
  ORDER_KEY = 'cs_cod_order_id'.freeze
  BUTTONS_KEY = 'cs_cod_buttons'.freeze
  ANSWER_KEY = 'cs_cod_answer_id'.freeze
  CONFIRMED_LABEL = 'cod-confirmed'.freeze
  CANCELLED_LABEL = 'cod-cancelled'.freeze
  CONFIRM_WORDS = ['confirm', 'confirmed', 'confirm order', 'yes', 'ok', 'haan', 'han', 'ji', 'jee'].freeze
  CANCEL_WORDS = ['cancel', 'cancelled', 'cancel order', 'no', 'nahi', 'nhi', 'cancel kar do', 'cancel kr do'].freeze

  pattr_initialize [:account!, :data!]

  # What the settings page needs: the store link, the WhatsApp numbers and the templates that fit.
  def self.settings_for(account)
    inboxes = Whatsapp::NumberHealth.cloud_inboxes(account)
    inbox = inboxes.find { |item| item.id == account.smart_feature(:cod_inbox_id) }
    {
      url: "#{ENV.fetch('FRONTEND_URL', '')}/webhooks/store_orders/#{account.smart_feature(:cod_token)}",
      inboxes: inboxes.map { |item| { id: item.id, name: item.name } },
      templates: inbox ? SmartFeatures::TemplateMessage.choices(inbox.channel, min_buttons: 2) : []
    }
  end

  # The customer's button tap (or a typed "confirm" / "cancel") on a chat waiting for a COD answer.
  def self.handle_answer(message)
    conversation = message.conversation
    attrs = conversation.additional_attributes || {}
    order = message.account.orders.find_by(id: attrs[ORDER_KEY], status: 'new') if attrs[ORDER_KEY]
    answer = choice(message.content, attrs[BUTTONS_KEY]) if order
    return if answer.nil?

    # ANSWER_KEY tells the AI not to reply to this message as well.
    conversation.update!(additional_attributes: attrs.except(ORDER_KEY, BUTTONS_KEY).merge(ANSWER_KEY => message.id))
    finish(order, answer == :confirm)
  end

  # The reply after the tap is the business's own text (Smart features > COD, {number} = order number) or ours.
  def self.finish(order, confirmed)
    order.update!(status: confirmed ? 'confirmed' : 'cancelled')
    order.conversation.add_labels([confirmed ? CONFIRMED_LABEL : CANCELLED_LABEL])
    number = order.external_ref.to_s.split.last || order.number.to_s
    own = order.account.smart_feature(confirmed ? :cod_confirmed_text : :cod_cancelled_text)
    text = own.present? ? own.gsub('{number}', number) : I18n.t("smart_features.cod.#{confirmed ? 'confirmed' : 'cancelled'}", number: number)
    SmartFeatures::ReviewRequest.send_text(order.conversation, text)
  end

  # Smart features > COD > "Ask again if no answer": the same template once more, while the order still waits.
  def self.remind(order)
    return unless order&.status == 'new' && order.account.smart_feature_on?(:cod_reminder)
    return unless order.conversation&.additional_attributes&.dig(ORDER_KEY) == order.id

    new(account: order.account, data: {}).ask_again(order)
  end

  def self.choice(text, buttons)
    answer = text.to_s.strip.downcase
    confirm, cancel = Array(buttons).map { |button| button.to_s.strip.downcase }
    return :confirm if answer == confirm || CONFIRM_WORDS.include?(answer)

    :cancel if answer == cancel || CANCEL_WORDS.include?(answer)
  end

  def perform
    return unless ready?

    phone = SmartFeatures::StoreOrder.phone(data['phone'])
    return if phone.blank? || account.orders.exists?(external_ref: ref) # stores send the same order again on retries

    conversation = sender.conversation_for(phone, data['name'])
    ask(conversation, create_order(conversation, phone))
  end

  def ask_again(order)
    sender.deliver(order.conversation, param_values(order)) if inbox && template
  end

  private

  def ready?
    account.smart_feature_on?(:cod_confirm) && inbox.present? && template.present? && (data['cod'] || !account.smart_feature_on?(:cod_only))
  end

  def inbox
    @inbox ||= Whatsapp::NumberHealth.cloud_inboxes(account).find { |item| item.id == account.smart_feature(:cod_inbox_id) }
  end

  def template
    @template ||= SmartFeatures::TemplateMessage.find(inbox.channel, account.smart_feature(:cod_template),
                                                     account.smart_feature(:cod_template_language), min_buttons: 2)
  end

  def sender
    SmartFeatures::TemplateMessage.new(inbox: inbox, template: template)
  end

  def ref
    data['ref'].to_s.truncate(80)
  end

  def create_order(conversation, phone)
    items = Array(data['items']).first(50)
    subtotal = items.sum { |item| item['price'].to_d * item['quantity'].to_i }
    total = data['total'].to_d
    attempts = 0
    begin
      account.orders.create!(
        number: account.orders.maximum(:number).to_i + 1, items: items, subtotal: subtotal, delivery_fee: [total - subtotal, 0].max,
        total: total, source: 'store', conversation: conversation, contact: conversation.contact, customer_phone: phone,
        customer_name: data['name'].to_s.truncate(120).presence, address: data['address'].to_s.truncate(1000).presence, external_ref: ref,
        store_order_id: data['store_id'].presence
      )
    rescue ActiveRecord::RecordNotUnique
      retry if (attempts += 1) < 3
      raise
    end
  end

  # Template variables are filled in this order: customer name, order number, total, items, address.
  def ask(conversation, order)
    conversation.update!(additional_attributes: (conversation.additional_attributes || {})
                           .merge(ORDER_KEY => order.id, BUTTONS_KEY => SmartFeatures::TemplateMessage.buttons(template)))
    sender.deliver(conversation, param_values(order))
    return unless account.smart_feature_on?(:cod_reminder)

    SmartFeatures::CodReminderJob.set(wait: account.smart_feature(:cod_reminder_hours).to_i.hours).perform_later(order.id)
  end

  def param_values(order)
    [
      order.customer_name || 'Customer', ref.split.last, (account.catalog_setting || CatalogSetting.new).money(order.total),
      order.items.map { |item| "#{item['name']} x#{item['quantity']}" }.join(', '), order.address
    ]
  end
end
