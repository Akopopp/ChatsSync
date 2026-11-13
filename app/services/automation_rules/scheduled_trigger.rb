# Timed automation events, checked every 10 minutes (AutomationRules::ScheduledTriggersJob):
# - customer_silent: we replied last and the customer has not answered for the rule's hours (trigger_value, like "24").
#   It runs once per silence: only after the customer writes again can it run again for that chat.
# - daily_time: every day at the rule's time in Pakistan time (trigger_value, like "10:00"), on the open chats
#   active in the last 30 days that match the rule's conditions.
class AutomationRules::ScheduledTrigger
  TIMEZONE = 'Asia/Karachi'.freeze
  MAX_CHATS = 300
  SILENT_WINDOW = 2.days
  DAILY_WINDOW = 30.minutes

  def self.perform_all
    AutomationRule.active.where(event_name: %w[customer_silent daily_time]).find_each do |rule|
      new(rule).perform
    rescue StandardError => e
      Rails.logger.warn("[ChatsSync automation] rule #{rule.id} failed: #{e.message}")
    end
  end

  pattr_initialize :rule

  def perform
    rule.event_name == 'customer_silent' ? run_silent : run_daily
  end

  private

  def run_silent
    hours = rule.trigger_value.to_i
    return unless hours.between?(1, 720)

    cutoff = hours.hours.ago
    open_chats.where(last_activity_at: (cutoff - SILENT_WINDOW)..).each do |conversation|
      silent_since(conversation, cutoff)&.then { |incoming_id| run_once(conversation, incoming_id) }
    end
  end

  # The id of the customer's last message when we replied after it and the customer stayed quiet past the cutoff.
  def silent_since(conversation, cutoff)
    last = conversation.messages.where(message_type: %i[incoming outgoing], private: false).reorder(id: :desc).first
    return unless last&.outgoing? && last.created_at <= cutoff && last.created_at > cutoff - SILENT_WINDOW

    conversation.messages.where(message_type: :incoming).maximum(:id).to_i
  end

  def run_once(conversation, incoming_id)
    attrs = conversation.additional_attributes || {}
    done = attrs['cs_silent_rules'] || {}
    return if done[rule.id.to_s] == incoming_id

    conversation.update!(additional_attributes: attrs.merge('cs_silent_rules' => done.merge(rule.id.to_s => incoming_id)))
    AutomationRules::CustomTrigger.run_rule(rule, conversation)
  end

  def run_daily
    now = Time.find_zone(TIMEZONE).now
    hour, minute = rule.trigger_value.to_s.split(':').map(&:to_i)
    due = now.change(hour: hour.to_i, min: minute.to_i)
    return unless now.between?(due, due + DAILY_WINDOW)

    key = "cs_automation_daily:#{rule.id}"
    return if Redis::Alfred.get(key) == now.to_date.iso8601

    Redis::Alfred.setex(key, now.to_date.iso8601, 2.days)
    open_chats.where(last_activity_at: 30.days.ago..).each { |conversation| AutomationRules::CustomTrigger.run_rule(rule, conversation) }
  end

  def open_chats
    rule.account.conversations.where(status: %i[open pending]).reorder(last_activity_at: :desc).limit(MAX_CHATS)
  end
end
