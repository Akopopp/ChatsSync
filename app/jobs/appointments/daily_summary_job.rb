# Every morning at 8 (in each account's own time zone) the admins get today's appointments by email.
class Appointments::DailySummaryJob < ApplicationJob
  queue_as :scheduled_jobs

  SEND_HOUR = 8

  def perform
    AppointmentSetting.where(enabled: true).includes(:account).find_each do |setting|
      zone = setting.zone
      next unless zone.now.hour == SEND_HOUR && setting.account.active?

      day = zone.now.beginning_of_day
      appointments = setting.account.appointments.booked.where(starts_at: day..day.end_of_day).order(:starts_at).to_a
      next if appointments.empty?

      AdministratorNotifications::AppointmentMailer.with(account: setting.account).daily_summary(appointments).deliver_later
    end
  end
end
