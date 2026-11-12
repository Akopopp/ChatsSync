# OpenAI-style chat with tool calling. Groq goes first (it does not train on API data),
# Gemini's OpenAI-compatible endpoint is the backup. Change the order with COPILOT_MODELS.
class CsCopilot::Llm
  ENDPOINTS = {
    'groq' => ['https://api.groq.com/openai/v1/chat/completions', 'GROQ_API_KEY'],
    'gemini' => ['https://generativelanguage.googleapis.com/v1beta/openai/chat/completions', 'GEMINI_API_KEY'],
    'mistral' => ['https://api.mistral.ai/v1/chat/completions', 'MISTRAL_API_KEY']
  }.freeze
  DEFAULT_MODELS = 'groq:openai/gpt-oss-120b,groq:openai/gpt-oss-20b,gemini:gemini-3.5-flash-lite,gemini:gemini-3.1-flash-lite,' \
                   'mistral:mistral-small-latest'.freeze

  # Returns the assistant message hash: { 'content' => ..., 'tool_calls' => [...] }
  # deadline: Ai::LlmClient.clock time by which the answer is needed
  def self.chat(messages:, tools:, deadline:)
    errors = []
    models.each do |provider, model|
      next errors << "#{model}: paused" if Ai::LlmClient.paused_for(model).positive?

      time_left = deadline - Ai::LlmClient.clock
      break errors << 'out of time' if time_left < 2

      message = request(provider, model, messages, tools, [Ai::LlmClient::READ_TIMEOUT, time_left - 0.5, 8].min)
      next if message.blank?

      Ai::LlmClient.track(model)
      return message
    rescue Ai::LlmClient::Unavailable => e
      Ai::LlmClient.pause(model, e.seconds)
      errors << "#{model}: #{e.message.truncate(160)}"
    rescue StandardError => e
      errors << "#{model}: #{e.message.truncate(160)}"
    end
    raise Ai::LlmClient::Error, "All Copilot models failed: #{errors.join(' | ').presence || 'no API key set'}"
  end

  def self.models
    ENV.fetch('COPILOT_MODELS', DEFAULT_MODELS).split(',').filter_map do |entry|
      provider, model = entry.strip.split(':', 2)
      [provider, model] if model.present? && ENDPOINTS.key?(provider) && ENV.fetch(ENDPOINTS[provider].last, nil).present?
    end
  end

  def self.request(provider, model, messages, tools, read_timeout)
    url, key_name = ENDPOINTS[provider]
    messages = with_thought_signatures(messages) if provider == 'gemini'
    body = { model: model, messages: messages, tools: tools, tool_choice: 'auto', temperature: 0.2 }
    body[provider == 'mistral' ? :max_tokens : :max_completion_tokens] = 2000
    body[:reasoning_effort] = 'low' if provider == 'groq'
    uri = URI(url)
    request = Net::HTTP::Post.new(uri, 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{ENV.fetch(key_name)}")
    request.body = body.to_json
    JSON.parse(Ai::LlmClient.post(uri, request, read_timeout: read_timeout).body).dig('choices', 0, 'message')
  end

  # Gemini 3 wants a thought signature on every earlier tool call. Calls made by another model (Groq) have none,
  # so they get Gemini's documented placeholder.
  def self.with_thought_signatures(messages)
    messages.map do |message|
      next message if message[:tool_calls].blank?

      signed = message[:tool_calls].map do |call|
        next call if call.dig('extra_content', 'google', 'thought_signature')

        call.merge('extra_content' => { 'google' => { 'thought_signature' => 'skip_thought_signature_validator' } })
      end
      message.merge(tool_calls: signed)
    end
  end
end
