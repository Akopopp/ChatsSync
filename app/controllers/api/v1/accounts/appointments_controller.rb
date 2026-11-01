class Api::V1::Accounts::AppointmentsController < Api::V1::Accounts::BaseController
  before_action :fetch_appointment, only: [:update]

  def index
    zone = Current.account.appointment_setting&.zone || ActiveSupport::TimeZone['Asia/Karachi']
    from = params[:from].present? ? zone.parse(params[:from]).beginning_of_day : zone.now.beginning_of_day
    to = params[:to].present? ? zone.parse(params[:to]).end_of_day : from + 30.days
    appointments = Current.account.appointments.where(starts_at: from..to).order(:starts_at).includes(:conversation).limit(500)
    render json: { payload: appointments.map { |appointment| appointment_json(appointment) } }
  end

  def update
    @appointment.update!(params.require(:appointment).permit(:status, :notes))
    render json: appointment_json(@appointment)
  end

  private

  def fetch_appointment
    @appointment = Current.account.appointments.find(params[:id])
  end

  def appointment_json(appointment)
    appointment.as_json(only: %i[id starts_at ends_at service customer_name customer_phone notes status source]).merge(
      conversation_id: appointment.conversation&.display_id
    )
  end
end
