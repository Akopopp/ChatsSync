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
  validates :notes, length: { maximum: 1000 }

  before_create { self.manage_token ||= SecureRandom.alphanumeric(24) }
  after_create_commit :tell_admins, unless: -> { source == 'team' }
  # Smart features > "Google Sheet" (does nothing unless switched on).
  after_create_commit -> { SmartFeatures::GoogleSheet.appointment(self) }
  # Smart features > "Ask for a review" (does nothing unless switched on).
  after_update_commit -> { SmartFeatures::ReviewRequest.ask(self) }, if: -> { saved_change_to_status? && status == 'done' }

  scope :booked, -> { where(status: 'booked') }
  scope :upcoming, -> { booked.where('starts_at >= ?', Time.current).order(:starts_at) }

  def label(zone)
    "#{starts_at.in_time_zone(zone).strftime('%a %-d %b, %-I:%M %p')}#{" (#{service})" if service.present?}"
  end

  # Page where the customer can change or cancel this booking.
  def manage_url
    update_column(:manage_token, SecureRandom.alphanumeric(24)) if manage_token.blank? # rubocop:disable Rails/SkipsModelValidations
    setting = account.appointment_setting
    "#{Appointments::PublicLink.url(setting)}/manage/#{manage_token}" if setting
  end

  private

  def tell_admins
    AdministratorNotifications::AppointmentMailer.with(account: account).new_booking(self).deliver_later
  end
end
