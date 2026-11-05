class Api::V1::Accounts::AppointmentSettingsController < Api::V1::Accounts::BaseController
  before_action :check_admin_authorization?
  before_action :fetch_setting

  def show
    render json: setting_json
  end

  def update
    @setting.update!(setting_params)
    render json: setting_json
  end

  # Tries again to create the WhatsApp booking form in the account's WhatsApp numbers.
  def setup_whatsapp_form
    Appointments::WhatsappFlowSetupJob.perform_later(Current.account, force: true)
    render json: setting_json
  end

  private

  def fetch_setting
    @setting = Current.account.appointment_setting || Current.account.create_appointment_setting!
  end

  def setting_params
    params.require(:appointment_setting).permit(
      :enabled, :timezone, :slot_minutes, :capacity, :days_ahead, :min_notice_minutes, :notes,
      services: %i[name minutes price], closed_dates: []
    ).tap do |permitted|
      permitted[:hours] = params.dig(:appointment_setting, :hours).to_unsafe_h if params.dig(:appointment_setting, :hours).respond_to?(:to_unsafe_h)
    end
  end

  def setting_json
    @setting.as_json(only: %i[enabled timezone slot_minutes capacity days_ahead min_notice_minutes hours services notes closed_dates]).merge(
      booking_page_url: Appointments::PublicLink.url(@setting),
      calendar_feed_url: "#{ENV.fetch('FRONTEND_URL', '').chomp('/')}/calendars/#{@setting.ics_token!}.ics",
      feature_available: Current.account.plan_feature?(:appointments),
      whatsapp_forms: whatsapp_forms
    )
  end

  def whatsapp_forms
    Current.account.inboxes.select { |inbox| Appointments::WhatsappFlow.supported?(inbox) }.map do |inbox|
      state = Appointments::WhatsappFlow.new(inbox: inbox).state
      { inbox: inbox.name, status: state['status'] || 'NOT_SET_UP', error: state['error'] }
    end
  end
end
