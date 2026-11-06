# Every 6 hours: reads each WhatsApp number's quality and message limit from Meta for accounts that switched on
# Smart features > "WhatsApp number health", and emails the admins when a number's quality drops.
class Whatsapp::NumberHealthJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    Account.active.where("smart_features ->> 'health_guard' = 'true'").find_each do |account|
      Whatsapp::NumberHealth.cloud_inboxes(account).each do |inbox|
        health = Whatsapp::NumberHealth.new(inbox: inbox)
        before, after = health.refresh!
        next unless Whatsapp::NumberHealth.dropped?(before, after)

        AdministratorNotifications::SmartFeaturesMailer.with(account: account).number_health_alert(health.summary).deliver_later
      end
    end
  end
end
