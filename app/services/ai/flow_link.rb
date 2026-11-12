# Lets the AI agent and the chatbot flow answer the same chat (AI agent > Setup > "Use my chatbot flows").
# The flow runs in the ChatsSync bot service (CHATSSYNC_BOT_URL). Each customer message goes to the flow first:
# button taps, flow questions and forms stay with the flow. Everything else the AI answers, and it can answer
# with one box of the flow by writing [BOX:id]; that box's buttons then continue the flow.
# The bot knows chats by their number in the account (display_id), as in Chatwoot's webhooks and API.
class Ai::FlowLink
  BOX_TAG = /\[BOX:\s*([\w-]+)\s*\]/i
  MAX_BOXES = 40

  # conversation is nil in the AI preview, where no flow box is offered.
  pattr_initialize [:account!, :conversation]

  def self.enabled_for?(account)
    account.ai_agent&.use_flows && ENV['CHATSSYNC_BOT_URL'].present?
  end

  # When true, the bot leaves this chat's new messages to ChatsSync (AgentBotListener marks them).
  def self.on?(conversation)
    agent = conversation.account.ai_agent
    return false unless agent&.enabled && enabled_for?(conversation.account) && agent.inbox_allowed?(conversation.inbox)

    conversation.inbox.agent_bot_inbox&.active? || false
  end

  # Gives the customer's message to the flow. full: the AI will not answer this chat, so the flow does everything
  # it does on its own (like starting from its first box). Returns true when the flow used the message.
  def route(message, full:)
    result = request(:post, '/api/ai/route', conversation_id: conversation.display_id, inbox_id: conversation.inbox_id,
                                             text: message.content.to_s, mode: full ? 'full' : 'input', sender: sender)
    stop_ai if result['handover']
    result['handled'] == true
  end

  def prompt_text(_question)
    return '' if boxes.empty?

    lines = boxes.map do |box|
      [box['id'], box['text'], ("buttons: #{box['options'].join(', ')}" if box['options'].present?)].compact_blank.join(' | ')
    end
    <<~TEXT
      Chatbot flow boxes (ready answers made by the business; the customer can tap their buttons):
      #{lines.join("\n")}
      - If one of these boxes answers the customer's message, reply with [BOX:<id>] on its own line.
        You may write one short line before it, but do not repeat what the box says.
      - Send at most one box per reply and only a box from this list. If no box fits, answer normally.
    TEXT
  end

  def apply(reply, roman_urdu:) # rubocop:disable Lint/UnusedMethodArgument
    id = reply[BOX_TAG, 1]
    @box_id = id if boxes.any? { |box| box['id'] == id }
    reply.gsub(BOX_TAG, '').strip
  end

  def extra_messages?
    @box_id.present?
  end

  # Sends the chosen box after the AI's own text, so the box and its buttons come last.
  def after_send
    return unless extra_messages?

    result = request(:post, '/api/ai/send-box', conversation_id: conversation.display_id, inbox_id: conversation.inbox_id,
                                                box_id: @box_id, sender: sender)
    stop_ai if result['handover']
  end

  private

  def boxes
    return @boxes if @boxes
    return @boxes = [] unless conversation && self.class.on?(conversation)

    all = Array(request(:get, "/api/ai/boxes?inbox_id=#{conversation.inbox_id}")['boxes'])
    @boxes = all.reject { |box| already_sent?(box) || (box['welcome'] && replied_before?) }.first(MAX_BOXES)
  end

  # The flow's welcome boxes only open a chat; once something was sent, the AI answers the question instead.
  def replied_before?
    @replied_before = conversation.messages.where(message_type: :outgoing, private: false).exists? if @replied_before.nil?
    @replied_before
  end

  # A box the customer already got in this chat (like the flow's welcome message) is not offered again,
  # so a question is answered instead of repeating that box. Text after a {{variable}} differs per customer.
  def already_sent?(box)
    start = box['text'].to_s.split('{{').first.to_s.squish.first(60)
    start.length >= 15 && sent_texts.any? { |text| text.include?(start) }
  end

  def sent_texts
    @sent_texts ||= conversation.messages.where(message_type: :outgoing, private: false).where.not(content: [nil, ''])
                                .reorder(id: :desc).limit(100).pluck(:content).map(&:squish)
  end

  # The flow reached a "Talk to a human" box: the team takes over and the AI stops in this chat.
  def stop_ai
    conversation.update!(additional_attributes: (conversation.additional_attributes || {}).merge('ai_off' => true))
    conversation.add_labels(['needs-human'])
    SmartFeatures::EmailAlert.send_for(conversation, 'handoff', 'A customer asked for your team in the chatbot flow')
  end

  def sender
    { name: conversation.contact&.name, phone: conversation.contact&.phone_number }
  end

  # The bot checks an account admin's login, the same way the Chatbot Builder does.
  def request(method, path, body = nil)
    token = account.administrators.first&.access_token&.token
    headers = { 'X-CS-Token' => token.to_s, 'X-CS-Account' => account.id.to_s, 'Content-Type' => 'application/json' }
    response = HTTParty.public_send(method, "#{ENV.fetch('CHATSSYNC_BOT_URL').chomp('/')}#{path}", headers: headers, timeout: 8,
                                                                                                  body: body&.to_json)
    return response.parsed_response if response.success? && response.parsed_response.is_a?(Hash)

    Rails.logger.warn("[ChatsSync AI] flow #{path} returned #{response.code}")
    {}
  rescue StandardError => e
    Rails.logger.warn("[ChatsSync AI] flow #{path} failed: #{e.message}")
    {}
  end
end
