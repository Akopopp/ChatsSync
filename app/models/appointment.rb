# A booked time with a customer, made by the AI, the booking page or the team.
class Appointment < ApplicationRecord
  STATUSES = %w[booked cancelled done no_show].freeze
  SOURCES = %w[ai page team].freeze

  belongs_to :account
  belongs_to :conversation, optional: true
  belongs_to :contact, optional: true

  validates :starts_at, :ends_at, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :source, inclusion: { in: SOURCES }
  validates :customer_name, length: { maximum: 120 }
  validates :customer_phone, length: { maximum: 40 }
  validates :service, length: { maximum: 80 }

  scope :booked, -> { where(status: 'booked') }
  scope :upcoming, -> { booked.where('starts_at >= ?', Time.current).order(:starts_at) }

  def label(zone)
    "#{starts_at.in_time_zone(zone).strftime('%a %-d %b, %-I:%M %p')}#{" (#{service})" if service.present?}"
  end
end
