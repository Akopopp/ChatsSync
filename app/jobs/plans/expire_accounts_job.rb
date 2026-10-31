# Suspends accounts the moment their plan or trial ends (no grace period).
# Off until PLAN_AUTO_SUSPEND=true, so plan dates can be reviewed before it goes live.
class Plans::ExpireAccountsJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    return unless ActiveModel::Type::Boolean.new.cast(ENV.fetch('PLAN_AUTO_SUSPEND', false))

    Account.active.where(plan_ends_at: ..Time.current).find_each do |account|
      account.update!(status: :suspended)
    end
  end
end
