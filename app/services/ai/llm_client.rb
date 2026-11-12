# Sends a chat to the first AI model that answers. Free models come first, so a
# rate limit (429) or an outage on one model just moves the request to the next.
# A rate-limited or failing model is skipped for a while (until its limit resets, or a few
# minutes after a server error or timeout), so requests don't wait on it.
# Models are "provider:model" pairs and can be changed with AI_TEXT_MODELS / AI_VISION_MODELS.
class Ai::LlmClient
  class Error < StandardError; end

  class Unavailable < Error
    attr_reader :seconds

    def initialize(message, seconds)
      super(message)
      @seconds = seconds
    end
  end

  GEMINI_URL = 'https://generativelanguage.googleapis.com/v1beta/models/%<model>s:generateContent'.freeze
  GROQ_URL = 'https://api.groq.com/openai/v1/chat/completions'.freeze
  # OpenAI-style providers. Mistral is a free backup (its free tier gives monthly credits); it only runs when MISTRAL_API_KEY is set.
  OPENAI_STYLE_URLS = { 'groq' => GROQ_URL, 'mistral' => 'https://api.mistral.ai/v1/chat/completions' }.freeze
  # Quick Flash Lite models answer first while their small free daily limit lasts; Gemma (large free limit, slower) takes over after.
  DEFAULT_TEXT_MODELS = 'gemini:gemini-3.5-flash-lite,gemini:gemini-3.1-flash-lite,gemini:gemma-4-26b-a4b-it,gemini:gemma-4-31b-it,' \
                        'groq:openai/gpt-oss-120b,groq:openai/gpt-oss-20b,mistral:mistral-small-latest'.freeze
  DEFAULT_VISION_MODELS = 'gemini:gemini-3.5-flash-lite,gemini:gemini-3.1-flash-lite'.freeze
  # Quickest models first, for things a person waits for on screen (like writing FAQs).
  DEFAULT_FAST_MODELS = 'groq:openai/gpt-oss-120b,gemini:gemini-3.5-flash-lite,groq:openai/gpt-oss-20b,gemini:gemini-3.1-flash-lite,' \
                        'gemini:gemma-4-26b-a4b-it'.freeze
  KEYS = { 'gemini' => 'GEMINI_API_KEY', 'groq' => 'GROQ_API_KEY', 'mistral' => 'MISTRAL_API_KEY' }.freeze
  USAGE_KEY = 'chatssync:ai_usage:%<date>s:%<model>s'.freeze
  PAUSE_KEY = 'chatssync:ai_paused:%<model>s'.freeze
  # Google resets free daily limits at midnight Pacific time, so usage is counted per Pacific day.
  QUOTA_TIMEZONE = 'America/Los_Angeles'.freeze
  FAILURE_PAUSE = 3.minutes.to_i
  READ_TIMEOUT = 25

  # messages: [{ role: 'user' | 'assistant', text: '...' }]
  # images:   [{ mime: 'image/jpeg', data: <binary> }], added to the last user message
  # within:   seconds the whole call may take (web requests are cut off after 15 seconds)
  # fast:     use the quickest models first
  def self.chat(system:, messages:, images: [], max_tokens: 500, within: nil, fast: false)
    new.chat(system: system, messages: messages, images: images, max_tokens: max_tokens, within: within, fast: fast)
  end

  def self.clock
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end

  def self.configured?
    KEYS.values.any? { |name| ENV.fetch(name, nil).present? }
  end

  # Today's request count and pause time left per model, for the Super Admin AI meter.
  def self.usage_today
    models = parse_models(ENV.fetch('AI_TEXT_MODELS', DEFAULT_TEXT_MODELS)) + parse_models(ENV.fetch('AI_VISION_MODELS', DEFAULT_VISION_MODELS)) +
             parse_models(ENV.fetch('COPILOT_MODELS', CsCopilot::Llm::DEFAULT_MODELS))
    models.map(&:last).uniq.index_with do |model|
      { used: Redis::Alfred.get(format(USAGE_KEY, date: quota_date, model: model)).to_i, paused_for: paused_for(model) }
    end
  end

  def self.quota_date
    Time.now.in_time_zone(QUOTA_TIMEZONE).to_date.iso8601
  end

  def self.track(model)
    key = format(USAGE_KEY, date: quota_date, model: model)
    Redis::Alfred.incr(key)
    Redis::Alfred.expire(key, 3.days.to_i)
  end

  def self.paused_for(model)
    Redis::Alfred.ttl(format(PAUSE_KEY, model: model)).to_i.clamp(0, nil)
  end

  def self.pause(model, seconds)
    Redis::Alfred.setex(format(PAUSE_KEY, model: model), 1, seconds)
  end

  # Raises Unavailable (with how long the model should rest) on a rate limit or server error,
  # Error on any other failure, such as a bad request.
  def self.check!(response)
    return if response.is_a?(Net::HTTPSuccess)

    message = "HTTP #{response.code} #{error_detail(response.body).squish.truncate(200)}"
    raise Unavailable.new(message, rest_seconds(response)) if response.code == '429'
    raise Unavailable.new(message, FAILURE_PAUSE) if response.code.start_with?('5')

    raise Error, message
  end

  # The provider's own error message, so a failure log says what was wrong.
  def self.error_detail(body)
    parsed = JSON.parse(body.to_s)
    Array.wrap(parsed).first&.dig('error', 'message').presence || body.to_s
  rescue JSON::ParserError
    body.to_s
  end

  # Sends the request; a timeout or dropped connection counts as the model being unavailable,
  # unless the wait was cut short because the caller is running out of time.
  def self.post(uri, request, read_timeout: READ_TIMEOUT)
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 5, read_timeout: read_timeout) { |http| http.request(request) }
    check!(response)
    response
  rescue Net::ReadTimeout => e
    raise Error, "timed out after #{read_timeout.round}s" if read_timeout < READ_TIMEOUT

    raise Unavailable.new(e.message, FAILURE_PAUSE)
  rescue Net::OpenTimeout, Errno::ECONNRESET, Errno::ECONNREFUSED, SocketError => e
    raise Unavailable.new(e.message, FAILURE_PAUSE)
  end

  def self.rest_seconds(response)
    body = response.body.to_s
    return response['retry-after'].to_i.clamp(10, 1.day.to_i) if response['retry-after'].present?

    if body.include?('PerDay')
      now = Time.now.in_time_zone(QUOTA_TIMEZONE)
      return (now.end_of_day - now).to_i + 60
    end

    body[/"retryDelay":\s*"(\d+)/, 1].to_i.clamp(10, 600)
  end

  def self.parse_models(list)
    list.to_s.split(',').filter_map do |entry|
      provider, model = entry.strip.split(':', 2)
      [provider, model] if model.present? && KEYS.key?(provider)
    end
  end

  def chat(system:, messages:, images: [], max_tokens: 500, within: nil, fast: false)
    @deadline = within && (self.class.clock + within)
    # With a time limit, one slow model may use at most 60% of it, so a quicker model still gets a turn.
    @attempt_limit = within && (within * 0.6)
    errors = []
    models(images.present?, fast).each do |provider, model|
      next errors << "#{model}: paused" if self.class.paused_for(model).positive?
      break errors << 'out of time' if time_left < 3

      text = if provider == 'gemini'
               gemini_chat(model, system, messages, images, max_tokens)
             else
               openai_style_chat(provider, model, system, messages, max_tokens)
             end
      next errors << "#{model}: empty reply" if text.blank?

      self.class.track(model)
      return text.strip
    rescue Unavailable => e
      self.class.pause(model, e.seconds)
      errors << "#{model}: #{e.message.truncate(160)}"
    rescue StandardError => e
      errors << "#{model}: #{e.message.truncate(160)}"
    end
    message = "All AI models failed: #{errors.join(' | ').presence || 'no API key set'}"
    Rails.logger.warn("[ChatsSync AI] #{message}")
    raise Error, message
  end

  private

  def models(vision, fast)
    list = if vision
             ENV.fetch('AI_VISION_MODELS', DEFAULT_VISION_MODELS)
           else
             fast ? ENV.fetch('AI_FAST_MODELS', DEFAULT_FAST_MODELS) : ENV.fetch('AI_TEXT_MODELS', DEFAULT_TEXT_MODELS)
           end
    self.class.parse_models(list).select { |provider, _| ENV.fetch(KEYS[provider], nil).present? }
  end

  def time_left
    @deadline ? @deadline - self.class.clock : READ_TIMEOUT
  end

  def read_timeout
    [READ_TIMEOUT, time_left - 1, @attempt_limit].compact.min
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
    # Gemma always thinks before answering, and its thinking counts as output.
    output_tokens = model.start_with?('gemma') ? max_tokens + 1500 : max_tokens
    body = { contents: contents, systemInstruction: { parts: [{ text: system }] },
             generationConfig: { temperature: 0.4, maxOutputTokens: output_tokens } }
    response = post_json(format(GEMINI_URL, model: model), body, 'x-goog-api-key' => ENV.fetch('GEMINI_API_KEY'))
    response.dig('candidates', 0, 'content', 'parts')&.reject { |part| part['thought'] }&.filter_map { |part| part['text'] }&.join
  end

  def openai_style_chat(provider, model, system, messages, max_tokens)
    body = {
      model: model,
      messages: [{ role: 'system', content: system }] + turns(messages).map { |m| { role: m[:role], content: m[:text] } },
      temperature: 0.4
    }
    # Groq's reasoning models think first, so they get room for that; Mistral answers straight away.
    body.merge!(provider == 'groq' ? { max_completion_tokens: max_tokens + 1000, reasoning_effort: 'low' } : { max_tokens: max_tokens })
    response = post_json(OPENAI_STYLE_URLS.fetch(provider), body, 'Authorization' => "Bearer #{ENV.fetch(KEYS.fetch(provider))}")
    response.dig('choices', 0, 'message', 'content')
  end

  def post_json(url, body, headers)
    uri = URI(url)
    request = Net::HTTP::Post.new(uri, { 'Content-Type' => 'application/json' }.merge(headers))
    request.body = body.to_json
    JSON.parse(self.class.post(uri, request, read_timeout: read_timeout).body)
  end
end
