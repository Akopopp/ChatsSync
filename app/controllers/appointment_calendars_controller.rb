# Calendar feed (Google Calendar "From URL") of one account's appointments, behind a secret link.
class AppointmentCalendarsController < ActionController::Base
  def show
    setting = AppointmentSetting.find_by!(ics_token: params[:token].to_s)
    send_data Appointments::IcsFeed.new(setting: setting).to_ics, type: 'text/calendar; charset=utf-8', disposition: 'inline',
                                                                   filename: 'appointments.ics'
  end
end
