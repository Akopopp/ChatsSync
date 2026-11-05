# ChatsSync plans: limits, monthly cycles, add-ons and usage for an account.
# An account without a plan has no limits, so existing clients are unaffected
# until a plan is assigned from Super Admin.
module AccountPlan
  extend ActiveSupport::Concern

  included do
    belongs_to :plan, optional: true
    has_many :usage_counters, dependent: :delete_all

    after_update_commit :unlock_plan_conversations,
                        if: -> { saved_change_to_plan_id? || saved_change_to_plan_addons? || saved_change_to_plan_ends_at? }
  end

  # Monthly usage resets on the same day of the month the plan started.
  def plan_cycle_start
    start = plan_starts_at || created_at
    now = Time.current
    return start if start >= now

    months = ((now.year * 12) + now.month) - ((start.year * 12) + start.month)
    cycle = start + months.months
    cycle > now ? cycle - 1.month : cycle
  end

  def plan_cycle_key
    plan_cycle_start.to_date.iso8601
  end

  # Accounts without a plan still get a cap on AI work, so one account cannot use up the shared AI quota.
  # Change the caps with these env vars; 0 means no cap.
  NO_PLAN_LIMITS = {
    'ai_replies_daily' => ['NO_PLAN_AI_REPLIES_DAILY', 100],
    'copilot_tasks_monthly' => ['NO_PLAN_COPILOT_TASKS_MONTHLY', 300]
  }.freeze

  # nil means unlimited
  def plan_limit(key)
    return no_plan_limit(key) if plan.nil?

    base = plan.limits[key.to_s]
    return nil unless base.is_a?(Integer)

    base + plan_addon(key)
  end

  def no_plan_limit(key)
    env, default = NO_PLAN_LIMITS[key.to_s]
    return if env.nil?

    ENV.fetch(env, default).to_i.nonzero?
  end

  def plan_addon(key)
    key = key.to_s
    addons = plan_addons || {}
    pack = Plan::CYCLE_KEYS.include?(key) ? addons.dig('packs', plan_cycle_key, key).to_i : 0
    addons.dig('recurring', key).to_i + pack
  end

  def plan_feature?(key)
    plan.nil? || plan.limits[key.to_s] != false
  end

  def plan_usage(key)
    case key.to_s
    when 'contacts_monthly' then monthly_active_contacts_count
    when 'agents' then account_users.count
    when 'whatsapp_numbers' then inboxes.where(channel_type: 'Channel::Whatsapp').count
    when 'facebook_pages' then facebook_inboxes(instagram: false).count
    when 'instagram_accounts' then inboxes.where(channel_type: 'Channel::Instagram').count + facebook_inboxes(instagram: true).count
    when 'campaigns_monthly' then campaigns.where(created_at: plan_cycle_start..).count
    when 'ai_replies_monthly' then usage_count('ai_replies', 'cycle')
    when 'ai_replies_daily' then usage_count('ai_replies', 'day')
    when 'copilot_tasks_monthly' then usage_count('copilot_tasks', 'cycle')
    when 'kb_faqs' then ai_knowledge_items.faqs.count
    when 'kb_files' then ai_knowledge_items.images.count
    end
  end

  def plan_limit_reached?(key)
    limit = plan_limit(key)
    limit.present? && plan_usage(key).to_i >= limit
  end

  def plan_usage_summary
    keys = Plan::LIMIT_KEYS | ((plan&.limits&.keys || []) - Plan::FEATURE_KEYS)
    keys.index_with { |key| { used: plan_usage(key), limit: plan_limit(key) } }
  end

  def monthly_active_contacts_count
    messages.where(message_type: :incoming, sender_type: 'Contact', created_at: plan_cycle_start..).distinct.count(:sender_id)
  end

  # Called by the AI service: increment_plan_usage!(:ai_replies)
  def increment_plan_usage!(metric, by = 1)
    { 'cycle' => plan_cycle_start.to_date, 'day' => plan_today }.each do |period, start|
      counter = usage_counters.create_or_find_by!(metric: metric.to_s, period: period, period_start: start)
      UsageCounter.update_counters(counter.id, count: by)
    end
  end

  def usage_count(metric, period)
    start = period == 'day' ? plan_today : plan_cycle_start.to_date
    usage_counters.find_by(metric: metric, period: period, period_start: start)&.count || 0
  end

  # A pack only adds to the current monthly cycle, e.g. +5,000 AI replies this month.
  def add_plan_pack!(key, amount)
    addons = (plan_addons || {}).deep_dup
    addons['packs'] ||= {}
    addons['packs'][plan_cycle_key] ||= {}
    addons['packs'][plan_cycle_key][key.to_s] = addons['packs'][plan_cycle_key][key.to_s].to_i + amount.to_i
    update!(plan_addons: addons)
  end

  # Extends from the current end date, or starts a fresh period if the plan already ended.
  def renew_plan!
    now = Time.current
    expired = plan_ends_at.blank? || plan_ends_at <= now
    update!(
      plan_starts_at: expired ? now : (plan_starts_at || now),
      plan_ends_at: (expired ? now : plan_ends_at) + plan.duration_days.days,
      status: :active
    )
  end

  def plan_locked_conversations
    conversations.where("conversations.additional_attributes ->> 'plan_locked' = 'true'")
  end

  private

  def plan_today
    Time.current.in_time_zone(Plan::TIMEZONE).to_date
  end

  def facebook_inboxes(instagram:)
    pages = instagram ? Channel::FacebookPage.where.not(instagram_id: nil) : Channel::FacebookPage.where(instagram_id: nil)
    inboxes.where(channel_type: 'Channel::FacebookPage', channel_id: pages.select(:id))
  end

  def unlock_plan_conversations
    # rubocop:disable Rails/SkipsModelValidations
    plan_locked_conversations.update_all("additional_attributes = additional_attributes - 'plan_locked'")
    # rubocop:enable Rails/SkipsModelValidations
  end
end
