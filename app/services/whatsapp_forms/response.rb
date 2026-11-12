# Reads a filled-in WhatsApp form from the customer's reply: saves the answers, shows them to the team as a private
# note in the chat, labels the chat with the form's name and fills the contact's email when the form asked for it.
module WhatsappForms::Response
  TOKEN = /\Acsform:(\d+)\z/

  module_function

  def record(message)
    data = JSON.parse(message.content_attributes['form_reply'].to_s)
    form = message.account.whatsapp_forms.find_by(id: data['flow_token'].to_s[TOKEN, 1])
    return if form.nil?

    answers = form.fields.to_h { |field| [field['label'], answer(field, data[field['key']])] }
    form.responses.create!(account_id: form.account_id, conversation_id: message.conversation_id, contact_id: message.sender_id,
                           answers: answers)
    tell_team(message.conversation, form, answers)
    fill_email(message.sender, form, data)
    AutomationRules::CustomTrigger.later('form_submitted', message.conversation)
  rescue JSON::ParserError
    nil
  end

  def answer(field, value)
    return field['options'][value.to_s.delete_prefix('o').to_i - 1].to_s if field['type'] == 'choice' && value.to_s.match?(/\Ao\d+\z/)

    value.to_s.squish
  end

  def tell_team(conversation, form, answers)
    lines = answers.map { |label, value| "#{label}: #{value.presence || '-'}" }
    conversation.messages.create!(account_id: conversation.account_id, inbox_id: conversation.inbox_id, message_type: :outgoing,
                                  private: true, content: ([I18n.t('whatsapp_forms.note_title', name: form.name)] + lines).join("\n"))
    conversation.add_labels(["form-#{form.name.parameterize}".first(40)])
  end

  def fill_email(contact, form, data)
    field = form.fields.find { |item| item['type'] == 'email' }
    email = data[field['key']].to_s.strip if field
    contact.update(email: email) if contact.is_a?(Contact) && contact.email.blank? && email.to_s.match?(URI::MailTo::EMAIL_REGEXP)
  end
end
