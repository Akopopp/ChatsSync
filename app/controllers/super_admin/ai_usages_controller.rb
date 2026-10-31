# Platform AI meter: how much of each free AI model ChatsSync used today, and which clients use AI most.
class SuperAdmin::AiUsagesController < SuperAdmin::ApplicationController
  # Free daily request limits seen in Google AI Studio and Groq (Oct 2026). Update if the providers change them.
  FREE_DAILY_LIMITS = {
    'gemma-4-31b-it' => 14_400, 'gemma-4-26b-a4b-it' => 14_400,
    'gemini-3.5-flash-lite' => 500, 'gemini-3.1-flash-lite' => 500,
    'openai/gpt-oss-120b' => 1000, 'openai/gpt-oss-20b' => 1000
  }.freeze

  def show
    @configured = Ai::LlmClient.configured?
    @models = Ai::LlmClient.usage_today.map { |model, usage| usage.merge(model: model, limit: FREE_DAILY_LIMITS[model]) }
    today = Time.current.in_time_zone(Plan::TIMEZONE).to_date
    @today_total = UsageCounter.where(metric: 'ai_replies', period: 'day', period_start: today).sum(:count)
    @top_accounts = UsageCounter.where(metric: 'ai_replies', period: 'cycle').where('period_start > ?', 32.days.ago.to_date)
                                .group(:account_id).sum(:count).sort_by { |_id, count| -count }.first(15)
    @account_names = Account.where(id: @top_accounts.map(&:first)).pluck(:id, :name).to_h
  end
end
