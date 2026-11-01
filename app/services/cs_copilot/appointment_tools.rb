# Copilot tools for appointments: see bookings and free times, book or cancel for a customer,
# and change the booking settings.
class CsCopilot::AppointmentTools
  READ_TOOLS = %w[list_appointments free_appointment_times].freeze
  WRITE_TOOLS = %w[book_appointment update_appointments update_appointment_settings].freeze
  ADMIN_TOOLS = %w[update_appointment_settings].freeze

  def self.fn(name, description, properties = {}, required = [])
    { type: 'function', function: { name: name, description: description,
                                     parameters: { type: 'object', properties: properties, required: required } } }
  end

  DATE = { type: 'string', description: 'Date as YYYY-MM-DD' }.freeze

  DEFINITIONS = [
    fn('list_appointments', 'List appointments in a date range (default: today and the next 7 days) with time, customer, service, ' \
                            'status and chat. "Kal ki appointments" means tomorrow\'s appointments.',
       { from_date: DATE, to_date: DATE, status: { type: 'string', enum: %w[booked cancelled done no_show all] } }),
    fn('free_appointment_times', 'Show free appointment times for the next days, or for one date.',
       { date: DATE, service: { type: 'string' } }),
    fn('book_appointment', 'Book an appointment for a customer at a free time (check free_appointment_times first).',
       { time: { type: 'string', description: 'YYYY-MM-DD HH:MM (24-hour clock)' }, name: { type: 'string' },
         phone: { type: 'string' }, conversation_id: { type: 'integer', description: 'Chat number, to link the booking to that chat' },
         service: { type: 'string' } }, ['time']),
    fn('update_appointments', 'Cancel appointments, or mark them done or no show, by id (get ids from list_appointments).',
       { ids: { type: 'array', items: { type: 'integer' } }, status: { type: 'string', enum: %w[cancelled done no_show] } },
       %w[ids status]),
    fn('update_appointment_settings', 'Turn appointment booking on or off, or change slot length, customers per slot, ' \
                                      'days customers can book ahead, minimum notice or notes for customers.',
       { enabled: { type: 'boolean' }, slot_minutes: { type: 'integer' }, capacity: { type: 'integer' },
         days_ahead: { type: 'integer' }, min_notice_minutes: { type: 'integer' }, notes: { type: 'string' } })
  ].freeze

  pattr_initialize [:account!, :user!]

  def self.handles?(name)
    (READ_TOOLS + WRITE_TOOLS).include?(name)
  end

  def execute(name, args)
    send("tool_#{name}", args.with_indifferent_access)
  end

  def summary(name, args)
    args = args.with_indifferent_access
    case name
    when 'book_appointment'
      "Book #{args[:time]}#{" (#{args[:service]})" if args[:service].present?} for #{args[:name].presence || chat_text(args) || 'the customer'}"
    when 'update_appointments' then "Mark #{Array(args[:ids]).size} appointment(s) as #{args[:status].to_s.tr('_', ' ')}"
    when 'update_appointment_settings' then "Change appointment settings: #{args.to_h.map { |key, value| "#{key} = #{value}" }.join(', ')}"
    end
  end

  private

  def setting
    @setting ||= account.appointment_setting ||
                 raise(CsCopilot::Tools::Error, 'Appointments are not set up yet. Open Settings → Appointments first.')
  end

  def tool_list_appointments(args)
    zone = setting.zone
    from = args[:from_date].present? ? zone.parse(args[:from_date]) : zone.now.beginning_of_day
    to = args[:to_date].present? ? zone.parse(args[:to_date]).end_of_day : from + 7.days
    scope = account.appointments.where(starts_at: from..to).order(:starts_at).includes(:conversation).limit(100)
    scope = scope.where(status: args[:status]) if args[:status].present? && args[:status] != 'all'
    { timezone: setting.timezone, appointments: scope.map do |appointment|
      { id: appointment.id, time: appointment.label(zone), customer: appointment.customer_name, phone: appointment.customer_phone,
        status: appointment.status, booked_by: appointment.source, chat: appointment.conversation&.display_id }.compact
    end }
  end

  def tool_free_appointment_times(args)
    minutes = setting.service_minutes(setting.resolve_service(args[:service]))
    slots = setting.free_slots(days: setting.days_ahead, minutes: minutes)
    slots = slots.select { |date, _| date.iso8601 == args[:date] } if args[:date].present?
    { enabled: setting.enabled, timezone: setting.timezone, services: setting.service_names,
      free_times: slots.first(7).to_h { |date, times| [date.strftime('%a %Y-%m-%d'), times.map { |time| time.strftime('%H:%M') }] } }
  end

  def tool_book_appointment(args)
    conversation = account.conversations.find_by(display_id: args[:conversation_id]) if args[:conversation_id].present?
    start = setting.zone.parse(args[:time].to_s)
    raise AppointmentSetting::SlotTaken if start.nil?

    appointment = setting.book!(start: start, service: setting.resolve_service(args[:service]), source: 'team',
                                conversation: conversation, contact: conversation&.contact, name: args[:name], phone: args[:phone])
    conversation&.messages&.create!(account_id: account.id, inbox_id: conversation.inbox_id, message_type: :activity,
                                    content: "Appointment booked by #{user.name}: #{appointment.label(setting.zone)}")
    { done: true, appointment_id: appointment.id, time: appointment.label(setting.zone) }
  rescue AppointmentSetting::SlotTaken, ArgumentError
    raise CsCopilot::Tools::Error, 'That time is not free. Check free_appointment_times and pick another time.'
  end

  def tool_update_appointments(args)
    raise CsCopilot::Tools::Error, 'Unknown status.' unless %w[cancelled done no_show].include?(args[:status])

    appointments = account.appointments.where(id: Array(args[:ids]))
    appointments.each { |appointment| appointment.update!(status: args[:status]) }
    { done: true, updated: appointments.size }
  end

  def tool_update_appointment_settings(args)
    setting.update!(args.slice(:enabled, :slot_minutes, :capacity, :days_ahead, :min_notice_minutes, :notes))
    { done: true }
  rescue ActiveRecord::RecordInvalid => e
    raise CsCopilot::Tools::Error, e.record.errors.full_messages.to_sentence
  end

  def chat_text(args)
    "chat ##{args[:conversation_id]}" if args[:conversation_id].present?
  end
end
