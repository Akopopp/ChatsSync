# Smart features > "Follow up with quiet customers": when the AI answered a customer who then went quiet
# (for example after asking a price), the AI sends one short, friendly follow-up after a few hours.
# It only writes inside the 24-hour reply window, only once per AI answer, and skips chats where a
# follow-up would not help (the model answers SKIP).
class Ai::FollowUpService
  pattr_initialize [:conversation!]

  WINDOW = 23.hours
  SKIP = 'SKIP'.freeze
  TASK = <<~TEXT.freeze
    FOLLOW-UP TASK: Your last reply above got no answer from the customer. Write ONE short, friendly follow-up
    (at most 2 sentences) that helps them decide, for example asking if they want to order, book or need anything else.
    Do not repeat your earlier answer, do not invent new offers or discounts, and do not greet them again.
    If a follow-up would not help (they already ordered, said no, said thanks/bye, or the chat is finished), answer only: #{SKIP}
  TEXT

  def self.due?(conversation, hours)
    last = conversation.messages.where(message_type: %i[incoming outgoing], private: false).reorder(id: :desc).first
    customer = conversation.messages.where(message_type: :incoming).reorder(id: :desc).first
    return false if last.nil? || customer.nil?
    # Only after an AI answer (not a chatbot flow or the team), never after a follow-up, and once per answer.
    return false unless last.content_attributes&.dig('ai_generated') && !last.content_attributes&.dig('ai_follow_up')
    return false if conversation.additional_attributes&.dig('cs_follow_up_for') == last.id

    last.created_at <= hours.hours.ago && customer.created_at >= WINDOW.ago
  end

  def perform
    agent = account.ai_agent
    return unless agent&.enabled && agent.inbox_allowed?(conversation.inbox)
    return if conversation.additional_attributes&.dig('ai_off') || account.plan_limit_reached?(:ai_replies_daily)

    mark_done
    text = write_follow_up(agent)
    return if text.blank? || text.include?(SKIP)

    conversation.messages.create!(account_id: account.id, inbox_id: conversation.inbox_id, message_type: :outgoing, content: text,
                                  sender: agent.bot, content_attributes: { 'ai_generated' => true, 'ai_follow_up' => true })
    account.increment_plan_usage!(:ai_replies)
  end

  private

  def account
    conversation.account
  end

  # Remember which AI answer was followed up, so there is only one follow-up per answer.
  def mark_done
    last_id = conversation.messages.where(message_type: :outgoing, private: false).reorder(id: :desc).pick(:id)
    conversation.update!(additional_attributes: (conversation.additional_attributes || {}).merge('cs_follow_up_for' => last_id))
  end

  def write_follow_up(agent)
    customer_text = conversation.messages.where(message_type: :incoming).reorder(id: :desc).limit(5).pluck(:content).compact.reverse
    system = Ai::PromptBuilder.new(agent: agent).system_prompt(customer_text.last.to_s, first_reply: false, earlier: customer_text.join("\n"))
    Ai::LlmClient.chat(system: "#{system}\n\n#{history}\n\n#{TASK}", messages: [{ role: 'user', text: 'Write the follow-up now.' }],
                       max_tokens: 200, within: 60).to_s.strip
  rescue StandardError => e
    Rails.logger.warn("[ChatsSync AI] follow-up failed for conversation #{conversation.id}: #{e.message}")
    nil
  end

  def history
    lines = conversation.messages.where(message_type: %i[incoming outgoing], private: false).reorder(id: :desc).limit(12)
                        .pluck(:message_type, :content).reverse
                        .map { |type, content| "#{type == 'incoming' ? 'Customer' : 'You'}: #{content.to_s.truncate(400)}" }
    "Chat so far:\n#{lines.join("\n")}"
  end
end
