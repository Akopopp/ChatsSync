# Sends a chat to the first AI model that answers. Free models come first, so a
# rate limit (429) or an outage on one model just moves the request to the next.
# Models are "provider:model" pairs and can be changed with AI_TEXT_MODELS / AI_VISION_MODELS.
class Ai::LlmClient
  class Error < StandardError; end

  GEMINI_URL = 'https://generativelanguage.googleapis.com/v1beta/models/%<model>s:generateContent'.freeze
  GROQ_URL = 'https://api.groq.com/openai/v1/chat/completions'.freeze
  DEFAULT_TEXT_MODELS = 'gemini:gemma-4-31b-it,gemini:gemma-4-26b-a4b-it,gemini:gemini-3.5-flash-lite,gemini:gemini-3.1-flash-lite,' \
                        'groq:openai/gpt-oss-120b,groq:openai/gpt-oss-20b'.freeze
  DEFAULT_VISION_MODELS = 'gemini:gemini-3.5-flash-lite,gemini:gemini-3.1-flash-lite'.freeze
  KEYS = { 'gemini' => 'GEMINI_API_KEY', 'groq' => 'GROQ_API_KEY' }.freeze
  USAGE_KEY = 'chatssync:ai_usage:%<date>s:%<model>s'.freeze

  # messages: [{ role: 'user' | 'assistant', text: '...' }]
  # images:   [{ mime: 'image/jpeg', data: <binary> }], added to the last user message
  def self.chat(system:, messages:, images: [], max_tokens: 500)
    new.chat(system: system, messages: messages, images: images, max_tokens: max_tokens)
  end

  def self.configured?
    KEYS.values.any? { |name| ENV.fetch(name, nil).present? }
  end

  # Today's request count per model, for the Super Admin AI meter.
  def self.usage_today
    date = Time.now.utc.to_date.iso8601
    (parse_models(DEFAULT_TEXT_MODELS) + parse_models(DEFAULT_VISION_MODELS)).map(&:last).uniq.index_with do |model|
      Redis::Alfred.get(format(USAGE_KEY, date: date, model: model)).to_i
    end
  end

  def self.parse_models(list)
    list.to_s.split(',').filter_map do |entry|
      provider, model = entry.strip.split(':', 2)
      [provider, model] if model.present? && KEYS.key?(provider)
    end
  end

  def chat(system:, messages:, images: [], max_tokens: 500)
    errors = []
    models(images.present?).each do |provider, model|
      text = provider == 'groq' ? groq_chat(model, system, messages, max_tokens) : gemini_chat(model, system, messages, images, max_tokens)
      next errors << "#{model}: empty reply" if text.blank?

      track(model)
      return text.strip
    rescue StandardError => e
      errors << "#{model}: #{e.message.truncate(160)}"
    end
    raise Error, "All AI models failed: #{errors.join(' | ').presence || 'no API key set'}"
  end

  private

  def models(vision)
    list = vision ? ENV.fetch('AI_VISION_MODELS', DEFAULT_VISION_MODELS) : ENV.fetch('AI_TEXT_MODELS', DEFAULT_TEXT_MODELS)
    self.class.parse_models(list).select { |provider, _| ENV.fetch(KEYS[provider], nil).present? }
  end

  # Gemini needs alternating user/model turns that start with the user.
  def turns(messages)
    merged = messages.each_with_object([]) do |message, result|
      role = message[:role] == 'assistant' ? 'assistant' : 'user'
      if result.last && result.last[:role] == role
        result.last[:text] = "#{result.last[:text]}\n#{message[:text]}"
      else
        result << { role: role, text: message[:text].to_s }
      end
    end
    merged.unshift({ role: 'user', text: '(conversation started)' }) if merged.first&.dig(:role) == 'assistant'
    merged
  end

  def gemini_chat(model, system, messages, images, max_tokens)
    contents = turns(messages).map { |m| { role: m[:role] == 'assistant' ? 'model' : 'user', parts: [{ text: m[:text] }] } }
    images.each do |image|
      contents.last[:parts] << { inline_data: { mime_type: image[:mime], data: Base64.strict_encode64(image[:data]) } }
    end
    body = { contents: contents, generationConfig: { temperature: 0.4, maxOutputTokens: max_tokens } }
    if model.start_with?('gemma')
      # Gemma models on the Gemini API take no system instruction, so it goes in the first turn.
      contents.first[:parts].unshift({ text: "#{system}\n\n---\n" })
    else
      body[:systemInstruction] = { parts: [{ text: system }] }
    end
    response = post_json(format(GEMINI_URL, model: model), body, 'x-goog-api-key' => ENV.fetch('GEMINI_API_KEY'))
    response.dig('candidates', 0, 'content', 'parts')&.reject { |part| part['thought'] }&.filter_map { |part| part['text'] }&.join
  end

  def groq_chat(model, system, messages, max_tokens)
    body = {
      model: model,
      messages: [{ role: 'system', content: system }] + turns(messages).map { |m| { role: m[:role], content: m[:text] } },
      temperature: 0.4,
      max_completion_tokens: max_tokens + 1000,
      reasoning_effort: 'low'
    }
    response = post_json(GROQ_URL, body, 'Authorization' => "Bearer #{ENV.fetch('GROQ_API_KEY')}")
    response.dig('choices', 0, 'message', 'content')
  end

  def post_json(url, body, headers)
    uri = URI(url)
    request = Net::HTTP::Post.new(uri, { 'Content-Type' => 'application/json' }.merge(headers))
    request.body = body.to_json
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 40) { |http| http.request(request) }
    raise Error, "HTTP #{response.code} #{response.body.to_s.truncate(200)}" unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body)
  end

  def track(model)
    key = format(USAGE_KEY, date: Time.now.utc.to_date.iso8601, model: model)
    Redis::Alfred.incr(key)
    Redis::Alfred.expire(key, 3.days.to_i)
  end
end
