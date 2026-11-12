# Smart features > "Email alerts" > "Also email me when": the owner's own rules in plain words.
# The AI checks them while it replies and adds [ALERT:why]; the team gets an email (the customer never sees the tag).
class Ai::AlertRules
  ALERT_TAG = /\[ALERT:\s*([^\]]+)\]/i

  pattr_initialize [:account!, :conversation]

  def self.enabled_for?(account)
    account.smart_feature_on?(:email_alerts) && account.smart_feature(:alert_rules).present?
  end

  def prompt_text(_question)
    <<~TEXT
      The business owner wants an email when: #{account.smart_feature(:alert_rules).squish}
      - If the customer's latest message matches this, add [ALERT:<a few words why>] at the very end of your reply. Otherwise do not add it.
    TEXT
  end

  def apply(reply, roman_urdu:) # rubocop:disable Lint/UnusedMethodArgument
    @reason = reply[ALERT_TAG, 1]&.squish
    reply.gsub(ALERT_TAG, '').strip
  end

  def after_send
    SmartFeatures::EmailAlert.send_for(conversation, 'rule', @reason) if @reason.present? && conversation
  end
end
