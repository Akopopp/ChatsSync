# Every 15 minutes: finds chats where the AI answered and the customer went quiet for the account's
# chosen number of hours, and sends one follow-up (Settings > Smart features > Follow up).
class Ai::FollowUpJob < ApplicationJob
  queue_as :scheduled_jobs

  PER_ACCOUNT = 50

  def perform
    Account.active.where("smart_features ->> 'follow_up' = 'true'").find_each do |account|
      next unless account.ai_agent&.enabled

      hours = account.smart_feature(:follow_up_hours)
      account.conversations.open.where(last_activity_at: Ai::FollowUpService::WINDOW.ago..hours.hours.ago)
             .order(last_activity_at: :desc).limit(PER_ACCOUNT).each do |conversation|
        Ai::FollowUpService.new(conversation: conversation).perform if Ai::FollowUpService.due?(conversation, hours)
      end
    end
  end
end
