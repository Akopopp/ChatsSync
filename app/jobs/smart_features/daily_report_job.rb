# Hourly: at 9 am (Plan::TIMEZONE) emails yesterday's numbers to the admins of accounts that switched on
# Settings > Smart features > "Daily report".
class SmartFeatures::DailyReportJob < ApplicationJob
  queue_as :scheduled_jobs

  SEND_HOUR = 9

  def perform
    return unless Time.current.in_time_zone(Plan::TIMEZONE).hour == SEND_HOUR

    Account.active.where("smart_features ->> 'daily_report' = 'true'").find_each do |account|
      stats = SmartFeatures::DailyReport.new(account: account).stats
      AdministratorNotifications::SmartFeaturesMailer.with(account: account).daily_report(stats).deliver_later
    end
  end
end
