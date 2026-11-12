# Automation rules for ChatsSync events that are not chat events: a new order, a booked appointment
# and a filled WhatsApp form. The rule's conditions (if any) are checked on that order's, booking's or form's chat.
class AutomationRules::CustomTrigger
  EVENTS = %w[order_created appointment_booked form_submitted].freeze

  def self.later(event_name, conversation)
    return if conversation.nil?
    return unless AutomationRule.exists?(account_id: conversation.account_id, event_name: event_name, active: true)

    AutomationRules::CustomTriggerJob.perform_later(event_name, conversation.id)
  end

  def self.run(event_name, conversation)
    AutomationRule.where(account_id: conversation.account_id, event_name: event_name, active: true).find_each do |rule|
      matched = rule.conditions.blank? ||
                AutomationRules::ConditionsFilterService.new(rule, conversation, { changed_attributes: {} }).perform.present?
      AutomationRules::ActionService.new(rule, conversation.account, conversation).perform if matched
    end
  end
end
