# Smart features > "Send from other apps": Zapier, Make, n8n, Google Forms or a website posts a phone number and a
# message to the account's secret link, and ChatsSync sends it on WhatsApp from the chosen number.
# Inside the 24-hour window plain text works; outside it Meta needs an approved template.
class SmartFeatures::AppMessage
  pattr_initialize [:account!, :params!]

  def perform
    return error('Pick the WhatsApp number on the Smart features page first.') if inbox.nil?
    return error('Send "phone" with the country code, like 923001234567.') if phone.blank?
    return error('Send "text" or "template".') if params['text'].blank? && params['template'].blank?

    conversation = sender.conversation_for(phone, params['name'])
    conversation.add_labels([params['label'].to_s.truncate(50)]) if params['label'].present?
    params['template'].present? ? send_template(conversation) : send_text(conversation)
  end

  private

  def inbox
    @inbox ||= Whatsapp::NumberHealth.cloud_inboxes(account).find { |item| item.id == account.smart_feature(:app_webhook_inbox_id) }
  end

  def phone
    digits = params['phone'].to_s.gsub(/\D/, '')
    digits = "92#{digits[1..]}" if digits.start_with?('03') && digits.length == 11 # Pakistani 03xx number
    "+#{digits}" if digits.length.between?(8, 15)
  end

  def sender(template = nil)
    SmartFeatures::TemplateMessage.new(inbox: inbox, template: template)
  end

  def send_template(conversation)
    template = SmartFeatures::TemplateMessage.templates(inbox.channel).find { |item| item['name'] == params['template'].to_s }
    return error("No approved template named #{params['template']} on this number.") if template.nil?

    sender(template).deliver(conversation, Array(params['values']))
    ok(conversation)
  end

  def send_text(conversation)
    return error('The customer has not written in the last 24 hours, so WhatsApp needs a "template".') unless conversation.can_reply?

    conversation.messages.create!(account_id: account.id, inbox_id: inbox.id, message_type: :outgoing,
                                  content: params['text'].to_s.truncate(4000))
    ok(conversation)
  end

  def ok(conversation)
    { ok: true, chat: conversation.display_id }
  end

  def error(text)
    { ok: false, error: text }
  end
end
