# Daily: sends the "Bring customers back" reminders for accounts that switched it on in Settings > Smart features.
class SmartFeatures::RepeatReminderJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    Account.active.where("smart_features ->> 'repeat_reminder' = 'true'").find_each do |account|
      SmartFeatures::RepeatReminder.new(account: account).perform
    end
  end
end
