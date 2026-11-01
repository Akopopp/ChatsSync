# How one account takes appointments: working hours per weekday (with breaks), days off,
# slot length, how many customers fit in one slot, services, and how far ahead customers can book.
class AppointmentSetting < ApplicationRecord
  class SlotTaken < StandardError; end

  DAYS = %w[0 1 2 3 4 5 6].freeze # Sunday = 0, same as Ruby's wday
  DEFAULT_HOURS = (1..6).to_h { |day| [day.to_s, [%w[10:00 18:00]]] }.freeze
  TIME = /\A([01]\d|2[0-3]):[0-5]\d\z/
  MAX_CLOSED_DATES = 100

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

  def resolve_service(name)
    return service_names.first if service_names.one?

    service_names.find { |service| service.casecmp?(name.to_s.strip) }
  end

  def closed_on?(date)
    closed_dates.include?(date.iso8601)
  end

  # Every start time of the open days from today: { Date => [[Time, free?], ...] }.
  # Times inside the minimum notice are left out; full times are kept with free? = false.
  def schedule(days: days_ahead, minutes: slot_minutes)
    now = zone.now
    earliest = now + min_notice_minutes.minutes
    booked = booked_ranges(now.beginning_of_day, now + (days + 1).days)
    (0...[days, days_ahead].min).each_with_object({}) do |offset, result|
      date = now.to_date + offset
      slots = day_slots(date, minutes).select { |start| start >= earliest }
      result[date] = slots.map { |start| [start, fits?(booked, start, start + minutes.minutes)] } if slots.any?
    end
  end

  # Free start times per day: { Date => [Time, ...] }, earliest first.
  def free_slots(days: days_ahead, minutes: slot_minutes, limit_per_day: nil)
    schedule(days: days, minutes: minutes).each_with_object({}) do |(date, slots), result|
      times = slots.select(&:last).map(&:first)
      times = times.first(limit_per_day) if limit_per_day
      result[date] = times if times.any?
    end
  end

  # any_time: the team may book outside the usual slots; only the number of customers per slot is checked.
  def slot_free?(start, minutes, except: nil, any_time: false)
    start = start.in_time_zone(zone)
    unless any_time
      return false if start < zone.now + min_notice_minutes.minutes || start > zone.now + days_ahead.days
      return false unless day_slots(start.to_date, minutes).include?(start)
    end
    fits?(booked_ranges(start - 1.day, start + 1.day, except), start, start + minutes.minutes)
  end

  # Books a time if it is still free. The lock stops two customers from taking the last place at once.
  def book!(start:, service: nil, source: 'ai', conversation: nil, contact: nil, name: nil, phone: nil, notes: nil)
    minutes = service_minutes(service)
    with_lock do
      raise SlotTaken unless slot_free?(start, minutes, any_time: source == 'team')

      account.appointments.create!(
        starts_at: start, ends_at: start + minutes.minutes, service: service.presence, source: source, notes: notes.presence,
        conversation: conversation, contact: contact, customer_name: name.to_s.strip.presence || contact&.name,
        customer_phone: phone.to_s.strip.presence || contact&.phone_number
      )
    end
  end

  def reschedule!(appointment, start, any_time: false)
    minutes = ((appointment.ends_at - appointment.starts_at) / 60).round
    with_lock do
      raise SlotTaken unless slot_free?(start, minutes, except: appointment.id, any_time: any_time)

      appointment.update!(starts_at: start, ends_at: start + minutes.minutes, status: 'booked', reminded_at: nil)
    end
  end

  # Secret link for Google Calendar / phone calendars, made the first time it is needed.
  def ics_token!
    update!(ics_token: SecureRandom.alphanumeric(32)) if ics_token.blank?
    ics_token
  end

  private

  def booked_ranges(from, to, except = nil)
    account.appointments.booked.where(starts_at: (from - 1.day)..to).where.not(id: except).pluck(:starts_at, :ends_at)
  end

  # Start times inside the working hours of one day, every slot_minutes. A day can have
  # several ranges (a lunch break splits the day in two).
  def day_slots(date, minutes)
    return [] if closed_on?(date)

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
    self.closed_dates = Array(closed_dates).filter_map { |date| iso_date(date) }.uniq.sort.last(MAX_CLOSED_DATES)
    self.services = Array(services).filter_map do |service|
      service = service.to_h.stringify_keys
      next if service['name'].blank?

      { 'name' => service['name'].to_s.strip.truncate(80), 'minutes' => service['minutes'].to_i.clamp(0, 480),
        'price' => service['price'].to_s.strip.truncate(30) }
    end
  end

  def iso_date(value)
    Date.iso8601(value.to_s).iso8601
  rescue Date::Error
    nil
  end

  def validate_timezone_and_hours
    errors.add(:timezone, 'is not valid') if ActiveSupport::TimeZone[timezone].nil?
    ranges = hours.values.flatten(1)
    valid = ranges.all? { |from, to| from.to_s.match?(TIME) && to.to_s.match?(TIME) && from < to }
    errors.add(:hours, 'must be like 10:00 to 18:00') unless valid
  end
end
