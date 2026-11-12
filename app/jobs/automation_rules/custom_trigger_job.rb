class AutomationRules::CustomTriggerJob < ApplicationJob
  queue_as :medium

  def perform(event_name, conversation_id)
    conversation = Conversation.find_by(id: conversation_id)
    AutomationRules::CustomTrigger.run(event_name, conversation) if conversation
  end
end
