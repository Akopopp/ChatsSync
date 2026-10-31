# Runs one Copilot request: the model may look things up (read tools) several times,
# then answers. If it wants to change something, the action is returned for the user to confirm.
class CsCopilot::Agent
  MAX_STEPS = 6
  MAX_RESULT_CHARS = 6000
  HISTORY_LIMIT = 12
  # Web requests are cut off after 15 seconds, so the whole run has to finish before that.
  TIME_LIMIT = 13

  pattr_initialize [:account!, :user!]

  # history: [{ role: 'user' | 'assistant', content: '...' }] as shown in the Copilot panel
  # uploads: { 'img1' => signed blob id } for pictures the user attached
  def run(history, uploads = {})
    @uploads = uploads
    recent = history.last(HISTORY_LIMIT).map { |item| { role: item[:role], content: item[:content].to_s } }
    messages = [{ role: 'system', content: system_prompt }] + recent
    deadline = Ai::LlmClient.clock + TIME_LIMIT
    MAX_STEPS.times do
      reply = CsCopilot::Llm.chat(messages: messages, tools: CsCopilot::Tools::DEFINITIONS, deadline: deadline)
      calls = Array(reply['tool_calls'])
      return { reply: reply['content'].to_s.strip } if calls.empty?

      messages << { role: 'assistant', content: reply['content'], tool_calls: calls }
      calls.each do |call|
        name = call.dig('function', 'name')
        args = parse_args(call.dig('function', 'arguments'))
        return pending(name, args, reply['content']) if tools.write?(name)

        messages << { role: 'tool', tool_call_id: call['id'], content: run_tool(name, args) }
      end
    end
    { reply: I18n.t('copilot.too_many_steps') }
  end

  def confirm(name, args)
    raise CsCopilot::Tools::Error, 'This action cannot be confirmed.' unless tools.write?(name)

    tools.execute(name, args)
    { reply: "#{I18n.t('copilot.done')} #{tools.summary(name, args)}." }
  end

  private

  def tools
    @tools ||= CsCopilot::Tools.new(account: account, user: user)
  end

  def pending(name, args, text)
    args = tools.with_uploads(name, args, @uploads || {})
    { reply: text.to_s.strip.presence, pending_action: { tool: name, args: args, summary: tools.summary(name, args) } }
  end

  # Any failure goes back to the model as an error, so it can tell the user instead of crashing.
  def run_tool(name, args)
    tools.execute(name, args).to_json.truncate(MAX_RESULT_CHARS)
  rescue CsCopilot::Tools::Error, ActiveRecord::RecordNotFound, ActiveRecord::RecordInvalid => e
    { error: e.message }.to_json
  rescue StandardError => e
    Rails.logger.error("[ChatsSync Copilot] #{name} failed: #{e.class} #{e.message}")
    { error: 'This lookup failed. Try asking in a different way.' }.to_json
  end

  def parse_args(raw)
    raw.is_a?(Hash) ? raw : JSON.parse(raw.presence || '{}')
  rescue JSON::ParserError
    {}
  end

  def system_prompt
    role = account.account_users.find_by(user_id: user.id)&.role
    now = Time.current.in_time_zone(CsCopilot::Tools::TIMEZONE).strftime('%A %d %B %Y, %I:%M %p')
    <<~PROMPT
      You are ChatsSync Copilot, the assistant inside the ChatsSync WhatsApp CRM for the business "#{account.name}".
      You help #{user.name} (role: #{role}) run their customer chats. Today is #{now} (Pakistan time).

      - Use the tools to look up real data before answering. Never guess numbers, names or messages.
      - To change anything, call the matching action tool. The user will see a confirm button, so do not ask "should I?" first.
      - Refer to chats as #number. Phone numbers are shortened for privacy.
      - Reply in the user's language and script (Roman Urdu in English letters, Urdu or English; never Hindi script).
      - Be short and clear. Write plain text with no markdown (no ** or # headings); use "- " for lists.
      - AI replies to customers come from "ChatsSync AI".
      - Pictures and videos the user attaches show as [Attached images: img1 (file name), ...]. To let the AI send them to customers,
        call add_product_images with a product name and price/details for each. If the name or price is missing, ask first.
      - To do the same thing to many chats, find them first, then pass all their numbers in conversation_ids (up to 50).
      - Chatbot flows and the media gallery are in the Chatbot Builder and Gallery pages; you cannot change them yet.
      - If something is not possible with your tools, say so and tell the user where in ChatsSync to do it.
    PROMPT
  end
end
