# == Schema Information
#
# Table name: plans
#
#  id            :bigint           not null, primary key
#  active        :boolean          default(TRUE), not null
#  duration_days :integer          default(30), not null
#  limits        :jsonb            not null
#  name          :string           not null
#  price         :integer          default(0), not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#
# Indexes
#
#  index_plans_on_name  (name) UNIQUE
#
class Plan < ApplicationRecord
  # Numeric limits. A blank value means unlimited.
  LIMIT_KEYS = %w[
    ai_replies_monthly ai_replies_daily copilot_tasks_monthly contacts_monthly
    agents whatsapp_numbers facebook_pages instagram_accounts
    campaigns_monthly chatbot_flows kb_faqs kb_files
  ].freeze
  # On/off switches. Missing means on.
  FEATURE_KEYS = %w[ai_voice_images ai_on_paid_chats appointments catalog_orders].freeze
  # Limits that count usage per monthly cycle; packs bought for a cycle only add to these.
  CYCLE_KEYS = %w[ai_replies_monthly copilot_tasks_monthly contacts_monthly campaigns_monthly].freeze
  TIMEZONE = ENV.fetch('PLAN_TIMEZONE', 'Asia/Karachi')

  has_many :accounts, dependent: :nullify

  validates :name, presence: true, uniqueness: true
  validates :duration_days, numericality: { only_integer: true, greater_than: 0 }
  validates :price, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  before_validation :normalize_limits

  scope :active, -> { where(active: true) }

  def self.cast_limits(raw)
    (raw || {}).to_h.each_with_object({}) do |(key, value), result|
      key = key.to_s.strip
      next if key.blank?

      if FEATURE_KEYS.include?(key)
        result[key] = ActiveModel::Type::Boolean.new.cast(value) != false
      elsif value.is_a?(Integer) || value.to_s.strip.match?(/\A\d+\z/)
        result[key] = value.to_i
      end
    end
  end

  private

  def normalize_limits
    self.limits = self.class.cast_limits(limits)
  end
end
