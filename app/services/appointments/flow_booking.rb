# Answers the WhatsApp booking form (Appointments::WhatsappFlowJson): which days are open, the times
# of a day, and the booking itself. The flow token says which chat the form was sent in.
class Appointments::FlowBooking
  TOKEN_PURPOSE = :whatsapp_booking_form

  def self.token_for(conversation)
    Rails.application.message_verifier(TOKEN_PURPOSE).generate(conversation.id, expires_in: 7.days)
  end

  pattr_initialize [:flow_token!]

  def respond(action, data)
    return expired if conversation.nil? || setting.nil?
    return book_screen if action == 'INIT' || action == 'BACK'

    case data['step']
    when 'times' then time_screen(data['date'], data['service'])
    when 'book' then book(data)
    else book_screen
    end
  end

  private

  def conversation
    return @conversation if defined?(@conversation)

    id = Rails.application.message_verifier(TOKEN_PURPOSE).verified(flow_token)
    @conversation = id && Conversation.find_by(id: id)
  end

  def account
    conversation.account
  end

  def setting
    @setting ||= account.appointment_setting if Appointments::AiBooking.enabled_for?(account)
  end

  def zone
    setting.zone
  end

  def book_screen(error = nil)
    schedule = setting.schedule
    free_days = schedule.select { |_, slots| slots.any?(&:last) }.keys
    first = free_days.first || zone.today
    last = zone.today + setting.days_ahead - 1
    closed = (first..last).reject { |date| free_days.include?(date) }.map(&:iso8601)
    { screen: 'BOOK', data: {
      business: account.ai_agent&.business_name.presence || account.name, services: service_options,
      show_services: setting.service_names.many?, min_date: first.iso8601, max_date: last.iso8601,
      unavailable_dates: closed, error: error.to_s, has_error: error.present?
    } }
  end

  def service_options
    names = setting.service_names.presence || ['Appointment']
    names.map do |name|
      service = setting.services.find { |item| item['name'] == name } || {}
      details = [("#{service['minutes']} min" if service['minutes'].to_i.positive?), service['price'].presence].compact.join(' · ')
      { id: name, title: name.truncate(30), description: details, enabled: true }
    end
  end

  def time_screen(date_text, service, error = nil)
    date = Date.iso8601(date_text.to_s)
    service = setting.resolve_service(service)
    slots = setting.schedule(days: (date - zone.today).to_i + 1, minutes: setting.service_minutes(service))[date] || []
    return book_screen(I18n.t('appointments.form.day_full')) if slots.none?(&:last)

    times = slots.map do |start, free|
      { id: start.strftime('%H:%M'), title: start.strftime('%-I:%M %p'), description: free ? '' : I18n.t('appointments.form.booked'),
        enabled: free }
    end
    { screen: 'TIME', data: {
      day_label: date.strftime('%A, %-d %B'), date: date.iso8601, service: service.to_s, times: times,
      customer_name: customer_name, error: error.to_s, has_error: error.present?
    } }
  rescue Date::Error
    book_screen
  end

  def customer_name
    name = conversation.contact&.name.to_s
    name.match?(/\A[a-z]+-[a-z]+-\d+\z/) || name.gsub(/\D/, '').length > 6 ? '' : name
  end

  def book(data)
    start = zone.parse("#{data['date']} #{data['time']}") || raise(AppointmentSetting::SlotTaken)
    appointment = setting.book!(start: start, service: setting.resolve_service(data['service']), conversation: conversation,
                                contact: conversation.contact, name: data['customer_name'].to_s.truncate(120))
    confirm_in_chat(appointment)
    { screen: 'DONE', data: { heading: I18n.t('appointments.form.done'), label: appointment.label(zone), appointment_id: appointment.id.to_s } }
  rescue AppointmentSetting::SlotTaken, ArgumentError
    time_screen(data['date'], data['service'], I18n.t('appointments.form.taken'))
  end

  # The customer gets the confirmation in the chat too, and the team sees a note.
  def confirm_in_chat(appointment)
    label = appointment.label(zone)
    conversation.add_labels(['appointment'])
    conversation.messages.create!(account_id: account.id, inbox_id: conversation.inbox_id, message_type: :activity,
                                  content: "Appointment booked in the WhatsApp form: #{label} – #{appointment.customer_name}")
    conversation.messages.create!(account_id: account.id, inbox_id: conversation.inbox_id, message_type: :outgoing,
                                  sender: account.ai_agent&.bot, content: I18n.t('appointments.form.confirmed', label: label))
  end

  def expired
    { screen: 'DONE', data: { heading: I18n.t('appointments.form.expired_heading'), label: I18n.t('appointments.form.expired'),
                              appointment_id: '' } }
  end
end
