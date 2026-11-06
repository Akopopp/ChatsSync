# Sends one approved WhatsApp template from a ChatsSync smart feature (COD confirmation, repeat reminders).
# The message is created in the customer's chat, so the team sees it and Meta's delivery ticks show on it.
# Template variables ({{1}} or {{name}}) are filled in the order they appear, from the values given.
class SmartFeatures::TemplateMessage
  PLACEHOLDER = /\{\{\s*([\w.]+)\s*\}\}/

  pattr_initialize [:inbox!, :template!]

  # Approved templates without a picture or variable in the header, optionally with at least N quick reply buttons.
  def self.templates(channel, min_buttons: 0)
    Array(channel.message_templates).select do |item|
      item['status'].to_s.casecmp?('approved') && buttons(item).size >= min_buttons &&
        Array(item['components']).none? { |part| header_needs_input?(part) }
    end
  end

  def self.find(channel, name, language, min_buttons: 0)
    templates(channel, min_buttons: min_buttons).find { |item| item['name'] == name && item['language'] == language }
  end

  # For the settings page: name, language and text of each template.
  def self.choices(channel, min_buttons: 0)
    templates(channel, min_buttons: min_buttons).map { |item| item.slice('name', 'language').merge('body' => body(item)) }
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

  # The open chat with this phone number on the inbox, or a new one.
  def conversation_for(phone, name)
    contact_inbox = ContactInboxWithContactBuilder.new(inbox: inbox, source_id: phone.delete('+'),
                                                       contact_attributes: { name: name.presence || phone, phone_number: phone }).perform
    contact_inbox.conversations.where.not(status: :resolved).last ||
      ::Conversation.create!(account_id: inbox.account_id, inbox_id: inbox.id, contact_id: contact_inbox.contact_id,
                             contact_inbox_id: contact_inbox.id)
  end

  def deliver(conversation, values)
    params = param_keys.each_with_index.to_h { |key, index| [key, values[index].to_s.squish.truncate(300).presence || '-'] }
    conversation.messages.create!(
      account_id: inbox.account_id, inbox_id: inbox.id, message_type: :outgoing,
      content: self.class.body(template).gsub(PLACEHOLDER) { params[Regexp.last_match(1)] },
      additional_attributes: { 'template_params' => { 'name' => template['name'], 'language' => template['language'],
                                                      'category' => template['category'], 'processed_params' => { 'body' => params } } }
    )
  end

  private

  def param_keys
    keys = self.class.body(template).scan(PLACEHOLDER).flatten.uniq
    keys.all? { |key| key.match?(/\A\d+\z/) } ? keys.sort_by(&:to_i) : keys
  end
end
