# Smart features > "STOP to unsubscribe": a WhatsApp customer who sends STOP gets the contact label "opted-out"
# and no more broadcasts (Whatsapp::OneoffCampaignService skips them); START brings them back.
# Following WhatsApp's opt-out rule keeps the number's quality rating high.
class Whatsapp::StopOptOut
  pattr_initialize [:message!]

  LABEL = 'opted-out'.freeze
  STOP_WORDS = ['stop', 'unsubscribe', 'band karo', 'band kro', 'band kar do', 'band kr do', 'band krdo', 'band kardo'].freeze
  START_WORDS = %w[start subscribe].freeze

  def self.keyword?(text)
    word = normalize(text)
    STOP_WORDS.include?(word) || START_WORDS.include?(word)
  end

  def self.normalize(text)
    text.to_s.downcase.gsub(/[^a-z ]/, ' ').squish
  end

  def perform
    return unless message.inbox.channel_type == 'Channel::Whatsapp'

    word = self.class.normalize(message.content)
    if STOP_WORDS.include?(word)
      contact.add_labels([LABEL])
      reply(I18n.t('smart_features.stop_opt_out.stopped'))
    elsif START_WORDS.include?(word) && contact.label_list.include?(LABEL)
      contact.update_labels(contact.label_list - [LABEL])
      reply(I18n.t('smart_features.stop_opt_out.started'))
    end
  end

  private

  def contact
    message.sender
  end

  def reply(text)
    conversation = message.conversation
    conversation.messages.create!(account_id: conversation.account_id, inbox_id: conversation.inbox_id, message_type: :outgoing,
                                  content: text)
  end
end
