# When the AI's goal is to collect leads: it asks the customer for the details the business wants
# (like name, city and budget) and its [LEAD:...] tag saves them on the contact for the team.
class Ai::LeadCapture
  LEAD_TAG = /\[LEAD:([^\]]*)\]/i

  # conversation is nil in the AI preview, where nothing is saved.
  pattr_initialize [:account!, :conversation]

  def self.enabled_for?(account)
    agent = account.ai_agent
    agent&.goal == 'leads' && agent.lead_field_names.any?
  end

  def prompt_text(_question = nil)
    fields = account.ai_agent.lead_field_names
    <<~TEXT
      Lead details:
      - Find out these details from the customer: #{fields.join(', ')}. Ask for one or two at a time, naturally,
        while helping them. Do not ask again for details they already gave.
      - When you have all of them, thank the customer, tell them the team will contact them, and put
        [LEAD:#{fields.map { |field| "#{field}=<value>" }.join('; ')}] on its own line.
    TEXT
  end

  def apply(reply, roman_urdu: false) # rubocop:disable Lint/UnusedMethodArgument
    match = reply.match(LEAD_TAG)
    return reply if match.nil?

    save(parse(match[1])) if conversation
    reply.gsub(LEAD_TAG, '').strip
  end

  private

  def parse(body)
    body.split(';').each_with_object({}) do |pair, details|
      key, value = pair.split('=', 2).map { |part| part.to_s.strip }
      details[key.truncate(40)] = value.truncate(200) if key.present? && value.present? && !value.match?(/\A\[.*\]\z|<value>/)
    end
  end

  def save(details)
    return if details.empty?

    contact = conversation.contact
    attributes = details.transform_keys { |key| "lead_#{key.parameterize(separator: '_')}" }
    contact.update!(custom_attributes: (contact.custom_attributes || {}).merge(attributes))
    name = details.find { |key, _| key.match?(/name|naam/i) }&.last
    contact.update!(name: name) if name.present? && placeholder_name?(contact)
    conversation.add_labels(['lead'])
    conversation.messages.create!(account_id: account.id, inbox_id: conversation.inbox_id, message_type: :activity,
                                  content: "Lead details from AI: #{details.map { |key, value| "#{key}: #{value}" }.join(' · ')}")
  end

  # Website chat visitors get names like "bitter-glade-754"; WhatsApp contacts are often just their number.
  def placeholder_name?(contact)
    phone = contact.phone_number.to_s.gsub(/\D/, '')
    contact.name.blank? || contact.name.match?(/\A[a-z]+-[a-z]+-\d+\z/) || (phone.present? && contact.name.gsub(/\D/, '') == phone)
  end
end
