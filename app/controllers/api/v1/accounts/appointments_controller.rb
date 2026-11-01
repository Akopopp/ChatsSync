# The team's appointments calendar: list, book for a customer, change time or status.
class Api::V1::Accounts::AppointmentsController < Api::V1::Accounts::BaseController
  before_action :fetch_setting
  before_action :fetch_appointment, only: [:update]

  def index
    appointments = Current.account.appointments.order(:starts_at).includes(:conversation)
    appointments = if params[:contact_id].present?
                     appointments.where(contact_id: params[:contact_id]).where('starts_at >= ?', 1.day.ago)
                   else
                     appointments.where(starts_at: range_start..range_end)
                   end
    render json: { payload: appointments.limit(500).map { |appointment| appointment_json(appointment) }, timezone: @setting.timezone,
                   services: @setting.services }
  end

  # Free start times of one day, for the booking form.
  def free_times
    date = Date.iso8601(params[:date].to_s)
    minutes = @setting.service_minutes(@setting.resolve_service(params[:service]))
    slots = @setting.schedule(days: [(date - @setting.zone.today).to_i + 1, 1].max, minutes: minutes)[date] || []
    render json: { times: slots.map { |start, free| { time: start.strftime('%H:%M'), free: free } } }
  rescue Date::Error
    render json: { times: [] }
  end

  def create
    conversation = Current.account.conversations.find_by(display_id: params[:conversation_id]) if params[:conversation_id].present?
    service = @setting.resolve_service(appointment_params[:service]) || appointment_params[:service].presence
    appointment = @setting.book!(start: start_time, service: service, source: 'team', conversation: conversation,
                                 contact: conversation&.contact, name: appointment_params[:customer_name],
                                 phone: appointment_params[:customer_phone], notes: appointment_params[:notes])
    note(appointment, "Appointment booked by #{Current.user.name}")
    render json: appointment_json(appointment)
  rescue AppointmentSetting::SlotTaken, ArgumentError
    render_slot_taken
  end

  def update
    if params[:date].present? && params[:time].present?
      @setting.reschedule!(@appointment, start_time, any_time: true)
      note(@appointment, "Appointment moved by #{Current.user.name}")
    end
    @appointment.update!(appointment_params.slice(:status, :notes))
    render json: appointment_json(@appointment)
  rescue AppointmentSetting::SlotTaken, ArgumentError
    render_slot_taken
  end

  private

  def fetch_setting
    @setting = Current.account.appointment_setting || Current.account.create_appointment_setting!
  end

  def fetch_appointment
    @appointment = Current.account.appointments.find(params[:id])
  end

  def appointment_params
    params.fetch(:appointment, {}).permit(:status, :notes, :service, :customer_name, :customer_phone)
  end

  def range_start
    params[:from].present? ? @setting.zone.parse(params[:from]).beginning_of_day : @setting.zone.now.beginning_of_day
  end

  def range_end
    params[:to].present? ? @setting.zone.parse(params[:to]).end_of_day : range_start + 30.days
  end

  def start_time
    @setting.zone.parse("#{params[:date]} #{params[:time]}") || raise(ArgumentError)
  end

  def note(appointment, text)
    return if appointment.conversation.nil?

    appointment.conversation.messages.create!(account_id: Current.account.id, inbox_id: appointment.conversation.inbox_id,
                                              message_type: :activity, content: "#{text}: #{appointment.label(@setting.zone)}")
  end

  def render_slot_taken
    render json: { error: I18n.t('errors.appointments.slot_taken') }, status: :unprocessable_entity
  end

  def appointment_json(appointment)
    appointment.as_json(only: %i[id starts_at ends_at service customer_name customer_phone notes status source contact_id]).merge(
      conversation_id: appointment.conversation&.display_id
    )
  end
end
