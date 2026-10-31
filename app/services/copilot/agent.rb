# Runs one Copilot request: the model may look things up (read tools) several times,
# then answers. If it wants to change something, the action is returned for the user to confirm.
class Copilot::Agent
  MAX_STEPS = 6
  MAX_RESULT_CHARS = 6000
  HISTORY_LIMIT = 12

  pattr_initialize [:account!, :user!]

  # history: [{ role: 'user' | 'assistant', content: '...' }] as shown in the Copilot panel
  def run(history)
    messages = [{ role: 'system', content: system_prompt }] + history.last(HISTORY_LIMIT).map { |item| { role: item[:role], content: item[:content].to_s } }
    MAX_STEPS.times do
      reply = Copilot::Llm.chat(messages: messages, tools: Copilot::Tools::DEFINITIONS)
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
    raise Copilot::Tools::Error, 'This action cannot be confirmed.' unless tools.write?(name)

    tools.execute(name, args)
    { reply: "#{I18n.t('copilot.done')} #{tools.summary(name, args)}." }
  end

  private

  def tools
    @tools ||= Copilot::Tools.new(account: account, user: user)
  end

  def pending(name, args, text)
    { reply: text.to_s.strip.presence, pending_action: { tool: name, args: args, summary: tools.summary(name, args) } }
  end

  def run_tool(name, args)
    tools.execute(name, args).to_json.truncate(MAX_RESULT_CHARS)
  rescue Copilot::Tools::Error, ActiveRecord::RecordNotFound, ActiveRecord::RecordInvalid => e
    { error: e.message }.to_json
  end

  def parse_args(raw)
    raw.is_a?(Hash) ? raw : JSON.parse(raw.presence || '{}')
  rescue JSON::ParserError
    {}
  end

  def system_prompt
    role = account.account_users.find_by(user_id: user.id)&.role
    <<~PROMPT
      You are ChatsSync Copilot, the assistant inside the ChatsSync WhatsApp CRM for the business "#{account.name}".
      You help #{user.name} (role: #{role}) run their customer chats. Today is #{Time.current.in_time_zone(Copilot::Tools::TIMEZONE).strftime('%A %d %B %Y, %I:%M %p')} (Pakistan time).

      - Use the tools to look up real data before answering. Never guess numbers, names or messages.
      - To change anything, call the matching action tool. The user will see a confirm button, so do not ask "should I?" first.
      - Refer to chats as #number. Phone numbers are shortened for privacy.
      - Reply in the user's language and script (Roman Urdu, Urdu or English). Be short and clear; use short bullet lists for data.
      - If something is not possible with your tools, say so and tell the user where in ChatsSync to do it.
    PROMPT
  end
end
