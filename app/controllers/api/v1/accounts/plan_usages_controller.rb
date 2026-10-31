class Api::V1::Accounts::PlanUsagesController < Api::V1::Accounts::BaseController
  def show
    account = Current.account
    plan = account.plan

    render json: {
      plan: plan && { id: plan.id, name: plan.name, price: plan.price, duration_days: plan.duration_days },
      starts_at: account.plan_starts_at,
      ends_at: account.plan_ends_at,
      cycle_start: account.plan_cycle_start,
      usage: account.plan_usage_summary.select { |_key, value| value[:limit].present? || value[:used].present? },
      features: Plan::FEATURE_KEYS.index_with { |key| account.plan_feature?(key) },
      locked_conversations: account.plan_locked_conversations.count,
      support_whatsapp: ENV.fetch('CHATSSYNC_SUPPORT_WHATSAPP', '923228413450')
    }
  end
end
