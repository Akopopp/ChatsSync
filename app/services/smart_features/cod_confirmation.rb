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
  PLACEHOLDER = /\{\{\s*([\w.]+)\s*\}\}/

  pattr_initialize [:account!, :data!]

  # What the settings page needs: the store link, the WhatsApp numbers and the templates that fit.
  def self.settings_for(account)
    inboxes = Whatsapp::NumberHealth.cloud_inboxes(account)
    inbox = inboxes.find { |item| item.id == account.smart_feature(:cod_inbox_id) }
    {
      url: "#{ENV.fetch('FRONTEND_URL', '')}/webhooks/store_orders/#{account.smart_feature(:cod_token)}",
      inboxes: inboxes.map { |item| { id: item.id, name: item.name } },
      templates: inbox ? templates(inbox.channel).map { |item| item.slice('name', 'language').merge('body' => body(item)) } : []
    }
  end

  # Approved templates with at least two quick reply buttons and no picture or variable in the header.
  def self.templates(channel)
    Array(channel.message_templates).select do |item|
      item['status'].to_s.casecmp?('approved') && buttons(item).size >= 2 && Array(item['components']).none? { |part| header_needs_input?(part) }
    end
  end

  def self.header_needs_input?(part)
    part['type'].to_s.casecmp?('header') && (part['format'] != 'TEXT' || part['text'].to_s.include?('{{'))
  end

  def self.buttons(template)
    part = Array(template['components']).find { |item| item['type'].to_s.casecmp?('buttons') }
    Array(part&.dig('buttons')).select { |button| button['type'].to_s.casecmp?('quick_reply') }.pluck('text')
  end

  def self.body(template)
    Array(template['components']).find { |item| item['type'].to_s.casecmp?('body') }&.dig('text').to_s
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

  def self.finish(order, confirmed)
    order.update!(status: confirmed ? 'confirmed' : 'cancelled')
    order.conversation.add_labels([confirmed ? CONFIRMED_LABEL : CANCELLED_LABEL])
    text = I18n.t("smart_features.cod.#{confirmed ? 'confirmed' : 'cancelled'}", number: order.external_ref.to_s.split.last || order.number)
    SmartFeatures::ReviewRequest.send_text(order.conversation, text)
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

    conversation = conversation_for(phone)
    ask(conversation, create_order(conversation, phone))
  end

  private

  def ready?
    account.smart_feature_on?(:cod_confirm) && inbox.present? && template.present? && (data['cod'] || !account.smart_feature_on?(:cod_only))
  end

  def inbox
    @inbox ||= Whatsapp::NumberHealth.cloud_inboxes(account).find { |item| item.id == account.smart_feature(:cod_inbox_id) }
  end

  def template
    @template ||= self.class.templates(inbox.channel).find do |item|
      item['name'] == account.smart_feature(:cod_template) && item['language'] == account.smart_feature(:cod_template_language)
    end
  end

  def ref
    data['ref'].to_s.truncate(80)
  end

  def conversation_for(phone)
    contact_inbox = ContactInboxWithContactBuilder.new(inbox: inbox, source_id: phone.delete('+'),
                                                       contact_attributes: { name: data['name'].presence || phone, phone_number: phone }).perform
    contact_inbox.conversations.where.not(status: :resolved).last ||
      ::Conversation.create!(account_id: account.id, inbox_id: inbox.id, contact_id: contact_inbox.contact_id, contact_inbox_id: contact_inbox.id)
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
        customer_name: data['name'].to_s.truncate(120).presence, address: data['address'].to_s.truncate(1000).presence, external_ref: ref
      )
    rescue ActiveRecord::RecordNotUnique
      retry if (attempts += 1) < 3
      raise
    end
  end

  # Template variables are filled in this order: customer name, order number, total, items, address.
  def ask(conversation, order)
    params = param_keys.each_with_index.to_h { |key, index| [key, param_values(order)[index].to_s.squish.truncate(300).presence || '-'] }
    conversation.update!(additional_attributes: (conversation.additional_attributes || {})
                           .merge(ORDER_KEY => order.id, BUTTONS_KEY => self.class.buttons(template)))
    conversation.messages.create!(
      account_id: account.id, inbox_id: inbox.id, message_type: :outgoing,
      content: self.class.body(template).gsub(PLACEHOLDER) { params[Regexp.last_match(1)] },
      additional_attributes: { 'template_params' => template_params(params) }
    )
  end

  def template_params(params)
    { 'name' => template['name'], 'language' => template['language'], 'category' => template['category'],
      'processed_params' => { 'body' => params } }
  end

  def param_keys
    keys = self.class.body(template).scan(PLACEHOLDER).flatten.uniq
    keys.all? { |key| key.match?(/\A\d+\z/) } ? keys.sort_by(&:to_i) : keys
  end

  def param_values(order)
    @param_values ||= [
      order.customer_name || 'Customer', ref.split.last, (account.catalog_setting || CatalogSetting.new).money(order.total),
      order.items.map { |item| "#{item['name']} x#{item['quantity']}" }.join(', '), order.address
    ]
  end
end
