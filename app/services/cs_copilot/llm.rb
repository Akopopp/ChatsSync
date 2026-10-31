# OpenAI-style chat with tool calling. Groq goes first (it does not train on API data),
# Gemini's OpenAI-compatible endpoint is the backup. Change the order with COPILOT_MODELS.
class CsCopilot::Llm
  ENDPOINTS = {
    'groq' => ['https://api.groq.com/openai/v1/chat/completions', 'GROQ_API_KEY'],
    'gemini' => ['https://generativelanguage.googleapis.com/v1beta/openai/chat/completions', 'GEMINI_API_KEY']
  }.freeze
  DEFAULT_MODELS = 'groq:openai/gpt-oss-120b,groq:openai/gpt-oss-20b,gemini:gemini-3.5-flash-lite,gemini:gemini-3.1-flash-lite'.freeze

  # Returns the assistant message hash: { 'content' => ..., 'tool_calls' => [...] }
  def self.chat(messages:, tools:)
    errors = []
    models.each do |provider, model|
      next errors << "#{model}: paused" if Ai::LlmClient.paused_for(model).positive?

      message = request(provider, model, messages, tools)
      next if message.blank?

      Ai::LlmClient.track(model)
      return message
    rescue Ai::LlmClient::RateLimited => e
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

  def self.request(provider, model, messages, tools)
    url, key_name = ENDPOINTS[provider]
    body = { model: model, messages: messages, tools: tools, tool_choice: 'auto', temperature: 0.2, max_completion_tokens: 2000 }
    body[:reasoning_effort] = 'low' if provider == 'groq'
    uri = URI(url)
    request = Net::HTTP::Post.new(uri, 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{ENV.fetch(key_name)}")
    request.body = body.to_json
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 60) { |http| http.request(request) }
    Ai::LlmClient.check!(response)

    JSON.parse(response.body).dig('choices', 0, 'message')
  end
end
