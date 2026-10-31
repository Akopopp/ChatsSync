# Writes FAQs (with similar ways customers ask the same thing) from the business info.
class Ai::FaqGenerator
  pattr_initialize [:agent!, :count]

  def perform
    reply = Ai::LlmClient.chat(system: system_prompt, messages: [{ role: 'user', text: request_text }], max_tokens: 3000)
    faqs = parse(reply)
    agent.account.increment_plan_usage!(:copilot_tasks)
    faqs.filter_map do |faq|
      item = agent.account.ai_knowledge_items.new(kind: 'faq', question: faq['question'].to_s.truncate(500), answer: faq['answer'].to_s.truncate(2000))
      item if item.save
    end
  end

  private

  def system_prompt
    'You write FAQ lists for small businesses in Pakistan that sell on WhatsApp. Reply with JSON only, no other text.'
  end

  def request_text
    <<~TEXT
      Business: #{agent.business_name.presence || agent.account.name}
      Business information:
      #{agent.business_info}

      Write #{count || 15} questions customers commonly ask on WhatsApp, with answers taken only from the business information.
      In each "question", list 3 to 5 ways customers ask it, separated by " / ", mixing Roman Urdu and English
      (for example: "Price kya hai? / Kitne ka hai? / What is the price?").
      Skip anything the business information does not answer.
      Return a JSON array like [{"question": "...", "answer": "..."}].
    TEXT
  end

  def parse(reply)
    json = reply[/\[.*\]/m]
    Array(JSON.parse(json.to_s)).select { |faq| faq.is_a?(Hash) && faq['question'].present? && faq['answer'].present? }
  rescue JSON::ParserError
    []
  end
end
