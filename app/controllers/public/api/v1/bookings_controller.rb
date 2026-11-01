# The public booking page of one account: free times, and booking one of them.
class Public::Api::V1::BookingsController < PublicController
  DAYS_SHOWN = 30

  before_action :set_setting

  def show
    minutes = @setting.service_minutes(@setting.resolve_service(params[:service]))
    days = @setting.free_slots(days: DAYS_SHOWN, minutes: minutes).map do |date, times|
      { date: date.iso8601, times: times.map { |time| time.strftime('%H:%M') } }
    end
    render json: { business_name: business_name, timezone: @setting.timezone, services: @setting.services,
                   notes: @setting.notes, days: days }
  end

  def create
    return render json: { error: 'missing_details' }, status: :unprocessable_entity if params[:name].blank? || phone_digits.length < 7

    start = @setting.zone.parse("#{params[:date]} #{params[:time]}")
    raise AppointmentSetting::SlotTaken if start.nil?

    appointment = @setting.book!(start: start, service: @setting.resolve_service(params[:service]), source: 'page',
                                 contact: contact, conversation: conversation, name: params[:name].to_s.truncate(120),
                                 phone: params[:phone].to_s.truncate(40))
    tell_team(appointment)
    render json: { label: appointment.label(@setting.zone) }
  rescue AppointmentSetting::SlotTaken, ArgumentError
    render json: { error: 'slot_taken' }, status: :conflict
  end

  private

  def set_setting
    @setting = AppointmentSetting.find_by!(public_token: params[:token])
    raise ActiveRecord::RecordNotFound unless @setting.account.active? && Appointments::AiBooking.enabled_for?(@setting.account)
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

  def tell_team(appointment)
    return if appointment.conversation.nil?

    appointment.conversation.messages.create!(
      account_id: appointment.account_id, inbox_id: appointment.conversation.inbox_id, message_type: :activity,
      content: "Appointment booked on the booking page: #{appointment.label(@setting.zone)} – #{appointment.customer_name}"
    )
  end
end
