# The account's appointments as an iCalendar feed, so Google Calendar or a phone calendar
# can subscribe to it and show every booking.
class Appointments::IcsFeed
  pattr_initialize [:setting!]

  def to_ics
    lines = ['BEGIN:VCALENDAR', 'VERSION:2.0', 'PRODID:-//ChatsSync//Appointments//EN', 'CALSCALE:GREGORIAN',
             "X-WR-CALNAME:#{escape("#{business_name} appointments")}", "X-WR-TIMEZONE:#{setting.timezone}"]
    appointments.each { |appointment| lines.concat(event(appointment)) }
    lines << 'END:VCALENDAR'
    "#{lines.join("\r\n")}\r\n"
  end

  private

  def appointments
    setting.account.appointments.where(status: %w[booked done]).where(starts_at: 30.days.ago..120.days.from_now).order(:starts_at)
  end

  def event(appointment)
    summary = [appointment.service, appointment.customer_name].compact_blank.join(' – ').presence || 'Appointment'
    description = ["Phone: #{appointment.customer_phone}", "Booked by: #{appointment.source}", appointment.notes].compact_blank.join("\n")
    ['BEGIN:VEVENT', "UID:appointment-#{appointment.id}@chatssync", "DTSTAMP:#{stamp(appointment.updated_at)}",
     "DTSTART:#{stamp(appointment.starts_at)}", "DTEND:#{stamp(appointment.ends_at)}", "SUMMARY:#{escape(summary)}",
     "DESCRIPTION:#{escape(description)}", 'END:VEVENT']
  end

  def stamp(time)
    time.utc.strftime('%Y%m%dT%H%M%SZ')
  end

  def escape(text)
    text.to_s.gsub('\\', '\\\\\\').gsub(';', '\;').gsub(',', '\,').gsub(/\r?\n/, '\n')
  end

  def business_name
    setting.account.ai_agent&.business_name.presence || setting.account.name
  end
end
