# == Schema Information
#
# Table name: ai_agents
#
#  id              :bigint           not null, primary key
#  business_info   :text
#  business_name   :string
#  enabled         :boolean          default(FALSE), not null
#  handoff_message :text
#  inbox_ids       :jsonb            not null
#  instructions    :text
#  reply_scope     :string           default("ad_leads"), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  account_id      :bigint           not null
#
# Indexes
#
#  index_ai_agents_on_account_id  (account_id) UNIQUE
#
# The ChatsSync AI agent that replies to customers for one account.
class AiAgent < ApplicationRecord
  REPLY_SCOPES = %w[ad_leads all].freeze
  TONES = %w[professional friendly formal].freeze
  CHANNEL_TYPES = %w[Channel::Whatsapp Channel::FacebookPage Channel::Instagram Channel::WebWidget Channel::Api].freeze
  BOT_NAME = 'ChatsSync AI'.freeze

  belongs_to :account

  validates :account_id, uniqueness: true
  validates :reply_scope, inclusion: { in: REPLY_SCOPES }
  validates :business_info, length: { maximum: 8000 }
  validates :instructions, length: { maximum: 3000 }
  validates :handoff_message, length: { maximum: 500 }
  validates :tone, inclusion: { in: TONES }
  validates :agent_name, length: { maximum: 60 }
  validates :reply_examples, length: { maximum: 3000 }

  def default_handoff_message
    handoff_message.presence || 'Thank you! Our team will reply to you shortly.'
  end

  def inbox_allowed?(inbox)
    return false unless CHANNEL_TYPES.include?(inbox.channel_type)

    inbox_ids.blank? || inbox_ids.map(&:to_i).include?(inbox.id)
  end

  # Replies on non-ad WhatsApp chats only when the business turns it on and the plan allows it.
  def all_chats?
    reply_scope == 'all' && account.plan_feature?(:ai_on_paid_chats)
  end

  def bot
    @bot ||= AgentBot.find_or_create_by!(account: account, name: BOT_NAME) do |agent_bot|
      agent_bot.description = 'Replies to customers using your business info and FAQs.'
    end
  end
end
