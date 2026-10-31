# Turns a customer's voice note into text with Groq Whisper (free tier: 2,000 a day).
class Ai::Transcriber
  URL = 'https://api.groq.com/openai/v1/audio/transcriptions'.freeze

  def self.transcribe(attachment)
    key = ENV.fetch('GROQ_API_KEY', nil)
    return nil if key.blank? || !attachment.file.attached?

    attachment.file.blob.open do |file|
      response = RestClient::Request.execute(
        method: :post, url: URL, timeout: 60,
        headers: { Authorization: "Bearer #{key}" },
        payload: { multipart: true, file: File.new(file.path, 'rb'), model: ENV.fetch('AI_TRANSCRIBE_MODEL', 'whisper-large-v3-turbo') }
      )
      JSON.parse(response.body)['text'].presence
    end
  rescue StandardError => e
    Rails.logger.warn("[ChatsSync AI] voice note transcription failed: #{e.message}")
    nil
  end
end
