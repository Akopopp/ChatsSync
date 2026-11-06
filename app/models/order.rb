# An order taken in chat by the AI or the team. Items keep the name and price at the time of ordering.
class Order < ApplicationRecord
  STATUSES = %w[new confirmed shipped delivered cancelled].freeze
  SOURCES = %w[ai team store].freeze

  belongs_to :account
  belongs_to :conversation, optional: true
  belongs_to :contact, optional: true

  validates :status, inclusion: { in: STATUSES }
  validates :source, inclusion: { in: SOURCES }
  validates :customer_name, length: { maximum: 120 }
  validates :customer_phone, length: { maximum: 40 }
  validates :address, :notes, length: { maximum: 1000 }

  # Smart features > "Ask for a review" (does nothing unless switched on).
  after_update_commit -> { SmartFeatures::ReviewRequest.ask(self) }, if: -> { saved_change_to_status? && status == 'delivered' }
  # Smart features > "Send sales to Meta" (does nothing unless switched on).
  after_commit -> { SmartFeatures::MetaSale.send_if_due(self) }, on: [:create, :update], if: -> { saved_change_to_status? || previously_new_record? }

  def summary(setting)
    lines = items.map { |item| "- #{item['name']} x#{item['quantity']} – #{setting.money(item['price'].to_d * item['quantity'])}" }
    lines << "Delivery: #{setting.money(delivery_fee)}" if delivery_fee.positive?
    lines << "Total: #{setting.money(total)}"
    lines.join("\n")
  end
end
