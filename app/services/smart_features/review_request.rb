# Smart features > "Ask for a review": after an order is delivered or an appointment is done, the customer is asked
# to rate it from 1 to 5. A 4 or 5 gets a thank-you and the Google review link (when set); 1 to 3 gets an apology,
# the "unhappy-customer" label and a private note so the team can call them.
# Only sent inside the 24-hour reply window, so no paid template is needed.
class SmartFeatures::ReviewRequest
  ASKED_KEY = 'cs_review_asked_at'.freeze
  ANSWER_KEY = 'cs_review_answer_id'.freeze
  ANSWER_WINDOW = 2.days
  REPLY_WINDOW = 23.hours
  UNHAPPY_LABEL = 'unhappy-customer'.freeze

  # Called when an order or appointment is finished.
  def self.ask(record)
    conversation = record.conversation
    account = record.account
    return unless conversation && account.smart_feature_on?(:review_request)
    return unless conversation.messages.where(message_type: :incoming).exists?(['created_at >= ?', REPLY_WINDOW.ago])
    return if asked_recently?(conversation)

    business = account.ai_agent&.business_name.presence || account.name
    send_text(conversation, I18n.t('smart_features.review_request.ask', business: business))
    conversation.update!(additional_attributes: (conversation.additional_attributes || {}).merge(ASKED_KEY => Time.current.to_i))
  end

  def self.asked_recently?(conversation)
    Time.zone.at(conversation.additional_attributes&.dig(ASKED_KEY).to_i) > ANSWER_WINDOW.ago
  end

  # The customer's rating, when the chat is waiting for one: "5", "4 stars", "⭐⭐⭐⭐".
  def self.rating(message)
    return unless asked_recently?(message.conversation)

    text = message.content.to_s.strip
    return text.count('⭐').clamp(1, 5) if text.match?(/\A⭐+\z/)

    text[/\A([1-5])(\s*(stars?|\/\s*5))?\s*\z/i, 1]&.to_i
  end

  def self.handle_answer(message)
    score = rating(message)
    return if score.nil?

    conversation = message.conversation
    # ANSWER_KEY tells the AI not to reply to this message as well.
    conversation.update!(additional_attributes: conversation.additional_attributes.except(ASKED_KEY).merge(ANSWER_KEY => message.id))
    score >= 4 ? thank(conversation) : apologize(conversation, score)
  end

  def self.thank(conversation)
    link = conversation.account.smart_feature(:review_link)
    key = link.present? ? 'smart_features.review_request.thanks_with_link' : 'smart_features.review_request.thanks'
    send_text(conversation, I18n.t(key, link: link))
  end

  def self.apologize(conversation, score)
    send_text(conversation, I18n.t('smart_features.review_request.sorry'))
    conversation.add_labels([UNHAPPY_LABEL])
    conversation.messages.create!(account_id: conversation.account_id, inbox_id: conversation.inbox_id, message_type: :activity,
                                  content: I18n.t('smart_features.review_request.team_note', score: score))
  end

  def self.send_text(conversation, text)
    conversation.messages.create!(account_id: conversation.account_id, inbox_id: conversation.inbox_id, message_type: :outgoing,
                                  content: text)
  end
end
