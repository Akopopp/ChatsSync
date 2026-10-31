# == Schema Information
#
# Table name: usage_counters
#
#  id           :bigint           not null, primary key
#  count        :integer          default(0), not null
#  metric       :string           not null
#  period       :string           not null
#  period_start :date             not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  account_id   :bigint           not null
#
# Indexes
#
#  index_usage_counters_on_account_metric_period  (account_id,metric,period,period_start) UNIQUE
#
class UsageCounter < ApplicationRecord
  PERIODS = %w[cycle day].freeze

  belongs_to :account

  validates :metric, presence: true
  validates :period, inclusion: { in: PERIODS }
end
