# Every 10 minutes: automation rules for quiet customers and daily times (AutomationRules::ScheduledTrigger).
class AutomationRules::ScheduledTriggersJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    AutomationRules::ScheduledTrigger.perform_all
  end
end
