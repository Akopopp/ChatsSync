# How one account takes appointments: working hours per weekday, slot length, how many
# customers fit in one slot, services, and how far ahead customers can book.
class AppointmentSetting < ApplicationRecord
  class SlotTaken < StandardError; end

  DAYS = %w[0 1 2 3 4 5 6].freeze # Sunday = 0, same as Ruby's wday
  DEFAULT_HOURS = (1..6).to_h { |day| [day.to_s, [%w[10:00 18:00]]] }.freeze
  TIME = /\A([01]\d|2[0-3]):[0-5]\d\z/

  belongs_to :account

  validates :account_id, uniqueness: true
  validates :slot_minutes, numericality: { only_integer: true, greater_than_or_equal_to: 5, less_than_or_equal_to: 480 }
  validates :capacity, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 100 }
  validates :days_ahead, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 90 }
  validates :min_notice_minutes, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :notes, length: { maximum: 1000 }
  validate :validate_timezone_and_hours

  before_validation :normalize
  before_create { self.public_token ||= SecureRandom.alphanumeric(20) }

  def zone
    ActiveSupport::TimeZone[timezone] || ActiveSupport::TimeZone['Asia/Karachi']
  end

  def service_names
    services.pluck('name').compact_blank
  end

  def service_minutes(name)
    services.find { |service| service['name'].to_s.casecmp?(name.to_s) }&.dig('minutes').to_i.nonzero? || slot_minutes
  end

  # Free start times per day: { Date => [Time, ...] }, earliest first.
  def free_slots(days: days_ahead, minutes: slot_minutes, limit_per_day: nil)
    now = zone.now
    earliest = now + min_notice_minutes.minutes
    booked = account.appointments.booked.where(starts_at: now..(now + (days + 1).days)).pluck(:starts_at, :ends_at)
    (0...[days, days_ahead].min).each_with_object({}) do |offset, result|
      date = now.to_date + offset
      times = day_slots(date, minutes).select { |start| start >= earliest && fits?(booked, start, start + minutes.minutes) }
      times = times.first(limit_per_day) if limit_per_day
      result[date] = times if times.any?
    end
  end

  def slot_free?(start, minutes)
    return false if start < zone.now + min_notice_minutes.minutes || start > zone.now + days_ahead.days

    day_slots(start.to_date, minutes).include?(start) &&
      fits?(account.appointments.booked.where(starts_at: (start - 1.day)..(start + 1.day)).pluck(:starts_at, :ends_at), start,
            start + minutes.minutes)
  end

  # Books a time if it is still free. The lock stops two customers from taking the last place at once.
  def book!(start:, service: nil, source: 'ai', conversation: nil, contact: nil, name: nil, phone: nil)
    minutes = service_minutes(service)
    with_lock do
      raise SlotTaken unless slot_free?(start, minutes)

      account.appointments.create!(
        starts_at: start, ends_at: start + minutes.minutes, service: service.presence, source: source,
        conversation: conversation, contact: contact, customer_name: name.to_s.strip.presence || contact&.name,
        customer_phone: phone.to_s.strip.presence || contact&.phone_number
      )
    end
  end

  def resolve_service(name)
    return service_names.first if service_names.one?

    service_names.find { |service| service.casecmp?(name.to_s.strip) }
  end

  private

  # Start times inside the working hours of one day, every slot_minutes.
  def day_slots(date, minutes)
    Array(hours[date.wday.to_s]).flat_map do |from, to|
      start = zone.parse("#{date} #{from}")
      finish = zone.parse("#{date} #{to}")
      slots = []
      while start + minutes.minutes <= finish
        slots << start
        start += slot_minutes.minutes
      end
      slots
    end
  end

  def fits?(booked, start, finish)
    booked.count { |from, to| from < finish && to > start } < capacity
  end

  def normalize
    self.hours = DEFAULT_HOURS if hours.blank? && new_record?
    self.hours = (hours || {}).to_h.slice(*DAYS).transform_values { |ranges| Array(ranges).map { |range| Array(range).first(2).map(&:to_s) } }
    self.services = Array(services).filter_map do |service|
      service = service.to_h.stringify_keys
      next if service['name'].blank?

      { 'name' => service['name'].to_s.strip.truncate(80), 'minutes' => service['minutes'].to_i.clamp(0, 480),
        'price' => service['price'].to_s.strip.truncate(30) }
    end
  end

  def validate_timezone_and_hours
    errors.add(:timezone, 'is not valid') if ActiveSupport::TimeZone[timezone].nil?
    valid = hours.values.flatten(1).all? { |from, to| from.to_s.match?(TIME) && to.to_s.match?(TIME) && from < to }
    errors.add(:hours, 'must be like 10:00 to 18:00') unless valid
  end
end
