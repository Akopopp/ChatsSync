class BookingPagesController < ActionController::Base
  def show
    @setting = AppointmentSetting.find_by!(public_token: params[:token])
    @title = @setting.account.ai_agent&.business_name.presence || @setting.account.name
  end
end
