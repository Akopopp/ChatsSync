class Ai::ReplyJob < ApplicationJob
  queue_as :medium

  LOCK_KEY = 'chatssync:ai_reply_lock:%<conversation_id>s'.freeze

  def perform(message_id, attempt = 1)
    message = Message.find_by(id: message_id)
    return if message.nil?

    lock_key = format(LOCK_KEY, conversation_id: message.conversation_id)
    # Another reply is being written for this chat: try again shortly so this message is not missed.
    unless Redis::Alfred.set(lock_key, message_id, nx: true, ex: 90)
      self.class.set(wait: 10.seconds).perform_later(message_id, attempt + 1) if attempt < 4
      return
    end

    begin
      Ai::ReplyService.new(conversation: message.conversation, message: message).perform
    rescue Ai::LlmClient::Error => e
      Rails.logger.warn("[ChatsSync AI] conversation #{message.conversation_id}: #{e.message}")
    ensure
      Redis::Alfred.delete(lock_key)
    end
  end
end
