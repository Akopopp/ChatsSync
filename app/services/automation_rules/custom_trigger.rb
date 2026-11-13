# Automation rules for ChatsSync events that are not chat events: a new order, a booked appointment,
# a filled WhatsApp form, and the timed events in AutomationRules::ScheduledTrigger (a quiet customer, a daily time).
# The rule's conditions (if any) are checked on that order's, booking's or form's chat.
class AutomationRules::CustomTrigger
  EVENTS = %w[order_created appointment_booked form_submitted].freeze
  TIMED_EVENTS = %w[customer_silent daily_time].freeze

  def self.later(event_name, conversation)
    return if conversation.nil?
    return unless AutomationRule.exists?(account_id: conversation.account_id, event_name: event_name, active: true)

    AutomationRules::CustomTriggerJob.perform_later(event_name, conversation.id)
  end

  def self.run(event_name, conversation)
    AutomationRule.where(account_id: conversation.account_id, event_name: event_name, active: true).find_each do |rule|
      run_rule(rule, conversation)
    end
  end

  def self.run_rule(rule, conversation)
    matched = rule.conditions.blank? ||
              AutomationRules::ConditionsFilterService.new(rule, conversation, { changed_attributes: {} }).perform.present?
    AutomationRules::ActionService.new(rule, conversation.account, conversation).perform if matched
  end
end
