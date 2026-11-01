# Public pages of one account: the appointment booking page and the menu / catalog page.
class BookingPagesController < ActionController::Base
  def show
    setting = AppointmentSetting.find_by!(public_token: params[:token])
    @title = business_name(setting.account)
  end

  def menu
    setting = CatalogSetting.find_by!(public_token: params[:token])
    @title = business_name(setting.account)
    render :show
  end

  private

  def business_name(account)
    account.ai_agent&.business_name.presence || account.name
  end
end
