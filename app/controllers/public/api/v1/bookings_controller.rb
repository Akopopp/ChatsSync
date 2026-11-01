# The public booking page of one account: the calendar of open days and times, booking a time,
# and the customer's own page to change or cancel a booking.
class Public::Api::V1::BookingsController < PublicController
  before_action :set_setting
  before_action :set_appointment, only: %i[manage reschedule cancel]

  def show
    minutes = @setting.service_minutes(@setting.resolve_service(params[:service]))
    days = @setting.schedule(minutes: minutes).map do |date, slots|
      { date: date.iso8601, times: slots.map { |start, free| { time: start.strftime('%H:%M'), free: free } } }
    end
    render json: { business_name: business_name, timezone: @setting.timezone, services: @setting.services,
                   notes: @setting.notes, today: @setting.zone.today.iso8601, last_day: (@setting.zone.today + @setting.days_ahead - 1).iso8601,
                   days: days }
  end

  def create
    return render json: { error: 'missing_details' }, status: :unprocessable_entity if params[:name].blank? || phone_digits.length < 7

    appointment = @setting.book!(start: start_time, service: @setting.resolve_service(params[:service]), source: 'page',
                                 contact: contact, conversation: conversation, name: params[:name].to_s.truncate(120),
                                 phone: params[:phone].to_s.truncate(40))
    tell_team(appointment, 'Appointment booked on the booking page')
    render json: { label: appointment.label(@setting.zone), manage_url: appointment.manage_url }
  rescue AppointmentSetting::SlotTaken, ArgumentError
    render json: { error: 'slot_taken' }, status: :conflict
  end

  def manage
    render json: { label: @appointment.label(@setting.zone), status: @appointment.status, service: @appointment.service,
                   name: @appointment.customer_name, upcoming: @appointment.starts_at.future? }
  end

  def reschedule
    @setting.reschedule!(@appointment, start_time)
    tell_team(@appointment, 'Customer changed the appointment time')
    render json: { label: @appointment.label(@setting.zone) }
  rescue AppointmentSetting::SlotTaken, ArgumentError
    render json: { error: 'slot_taken' }, status: :conflict
  end

  def cancel
    @appointment.update!(status: 'cancelled')
    tell_team(@appointment, 'Customer cancelled the appointment')
    render json: { status: 'cancelled' }
  end

  private

  def set_setting
    @setting = AppointmentSetting.find_by!(public_token: params[:token])
    raise ActiveRecord::RecordNotFound unless @setting.account.active? && Appointments::AiBooking.enabled_for?(@setting.account)
  end

  # Only bookings that are still coming up can be changed.
  def set_appointment
    @appointment = @setting.account.appointments.find_by!(manage_token: params[:manage_token].to_s)
    return if action_name == 'manage' || (@appointment.status == 'booked' && @appointment.starts_at.future?)

    render json: { error: 'not_changeable' }, status: :unprocessable_entity
  end

  def start_time
    @setting.zone.parse("#{params[:date]} #{params[:time]}") || raise(ArgumentError)
  end

  def business_name
    @setting.account.ai_agent&.business_name.presence || @setting.account.name
  end

  def phone_digits
    @phone_digits ||= params[:phone].to_s.gsub(/\D/, '')
  end

  # Links the booking to the customer's existing contact and latest chat, matched on the last 10 digits.
  def contact
    return @contact if defined?(@contact)

    @contact = @setting.account.contacts.where('phone_number LIKE ?', "%#{phone_digits.last(10)}").first
  end

  def conversation
    contact&.conversations&.order(last_activity_at: :desc)&.first
  end

  def tell_team(appointment, text)
    return if appointment.conversation.nil?

    appointment.conversation.messages.create!(
      account_id: appointment.account_id, inbox_id: appointment.conversation.inbox_id, message_type: :activity,
      content: "#{text}: #{appointment.label(@setting.zone)} – #{appointment.customer_name}"
    )
  end
end
