# What the AI agent knows and does about appointments for one chat:
# it gets the free times in its instructions, and its [BOOK:...] / [CANCEL_BOOKING] tags
# are turned into real bookings here (the time is checked again, so nothing is double booked).
class Appointments::AiBooking
  BOOK_TAG = /\[BOOK:\s*([^\]|]+)\|?([^\]|]*)\|?([^\]]*)\]/i
  CANCEL_TAG = /\[CANCEL_BOOKING\]/i
  DAYS_SHOWN = 5
  SLOTS_PER_DAY = 12

  # conversation is nil in the AI preview, where nothing is booked.
  pattr_initialize [:account!, :conversation]

  def self.enabled_for?(account)
    setting = account.appointment_setting
    setting&.enabled && account.plan_feature?(:appointments)
  end

  def setting
    @setting ||= account.appointment_setting
  end

  def prompt_text(_question = nil)
    zone = setting.zone
    days = setting.free_slots(days: DAYS_SHOWN, limit_per_day: SLOTS_PER_DAY).map do |date, times|
      "#{date.strftime('%a %-d %b')}: #{times.map { |time| time.strftime('%H:%M') }.join(', ')}"
    end
    <<~TEXT
      Appointments:
      - You can book appointments. Today is #{zone.now.strftime('%A %-d %B %Y')} (#{setting.timezone}).
      - Services: #{services_text}
      - Free times (24-hour clock): #{days.presence&.join('; ') || 'no free times in the next days'}
      - Offer 3 to 5 of these times, not the whole list. Only book a time from this list.
      - When the customer has chosen a time and told you their name, write one short thank-you line and put
        [BOOK:YYYY-MM-DD HH:MM|Customer name|Service] on its own line (leave Service empty if there is only one).
        Do not say the booking is confirmed yourself: the system checks the time and adds the confirmation.
      - If the customer wants to cancel, confirm and put [CANCEL_BOOKING] on its own line. To change the time,
        put [CANCEL_BOOKING] and then a new [BOOK:...].
      #{existing_text}#{page_text}#{setting.notes.present? ? "- Notes from the business: #{setting.notes}\n" : ''}
    TEXT
  end

  # Turns the tags in the AI reply into bookings. Returns the reply text to send.
  def apply(reply, roman_urdu:)
    text = reply.dup
    messages = []
    if text.match?(CANCEL_TAG)
      text = text.gsub(CANCEL_TAG, '')
      cancelled = cancel_upcoming
      messages << cancelled_text(cancelled, roman_urdu) if cancelled
    end
    if (match = text.match(BOOK_TAG))
      text = text.gsub(BOOK_TAG, '')
      messages << book(match[1], match[2], match[3], roman_urdu: roman_urdu)
    end
    [text.strip, *messages.compact].compact_blank.join("\n")
  end

  private

  def contact
    conversation&.contact
  end

  def services_text
    return 'one general appointment' if setting.services.empty?

    setting.services.map do |service|
      [service['name'], ("#{service['minutes']} min" if service['minutes'].to_i.positive?), service['price'].presence].compact.join(', ')
    end.join('; ')
  end

  def existing_text
    return '' if contact.nil?

    existing = account.appointments.upcoming.where(contact_id: contact.id).first
    existing ? "- This customer already has an appointment: #{existing.label(setting.zone)}.\n" : ''
  end

  def page_text
    url = Appointments::PublicLink.url(setting)
    url ? "- If the customer wants to see the full calendar, send this link: #{url}\n" : ''
  end

  def cancel_upcoming
    return if contact.nil?

    appointment = account.appointments.upcoming.where(contact_id: contact.id).first
    appointment&.update!(status: 'cancelled')
    appointment
  end

  def book(time_text, name, service, roman_urdu:)
    service = setting.resolve_service(service)
    start = parse_time(time_text)
    return "(Preview: would book #{start&.strftime('%a %-d %b, %-I:%M %p')} for #{name})" if conversation.nil? && start
    raise AppointmentSetting::SlotTaken if start.nil?

    appointment = setting.book!(start: start, service: service, conversation: conversation, contact: contact, name: name)
    tell_team(appointment)
    label = appointment.label(setting.zone)
    roman_urdu ? "✅ Appointment confirm: #{label}" : "✅ Appointment confirmed: #{label}"
  rescue AppointmentSetting::SlotTaken
    roman_urdu ? 'Maazrat, ye time ab available nahi hai. Koi aur time bata dein.' : 'Sorry, that time is no longer free. Please choose another time.'
  end

  def cancelled_text(appointment, roman_urdu)
    label = appointment.label(setting.zone)
    roman_urdu ? "Aap ki appointment (#{label}) cancel kar di gayi hai." : "Your appointment (#{label}) has been cancelled."
  end

  def parse_time(text)
    setting.zone.parse(text.to_s.strip)
  rescue ArgumentError
    nil
  end

  def tell_team(appointment)
    conversation.add_labels(['appointment'])
    conversation.messages.create!(
      account_id: account.id, inbox_id: conversation.inbox_id, message_type: :activity,
      content: "Appointment booked by AI: #{appointment.label(setting.zone)} – #{appointment.customer_name}"
    )
  end
end
