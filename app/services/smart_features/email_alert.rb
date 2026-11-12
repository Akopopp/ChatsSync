# Smart features > "Email alerts": the account admins get an email when a chat needs them:
# a new order taken by the AI, the AI passing a chat to the team, or a customer message that matches
# the owner's own alert rules (the AI checks those while it replies, see Ai::AlertRules).
class SmartFeatures::EmailAlert
  # event: 'order', 'handoff' or 'rule'. One email per chat and event every 10 minutes.
  def self.send_for(conversation, event, reason)
    account = conversation.account
    return unless account.smart_feature_on?(:email_alerts) && (event == 'rule' || account.smart_feature_on?("alert_#{event}"))
    return unless Redis::Alfred.set("cs:email_alert:#{conversation.id}:#{event}", 1, nx: true, ex: 10.minutes.to_i)

    deliver(conversation, reason)
  end

  # Also used by Automation rules ("Email the admins").
  def self.deliver(conversation, reason)
    account = conversation.account
    contact = conversation.contact
    last = conversation.messages.where(message_type: :incoming).last&.content.to_s.squish.truncate(300)
    meta = { 'reason' => reason.to_s.truncate(150), 'name' => contact&.name.to_s, 'phone' => contact&.phone_number.to_s,
             'inbox' => conversation.inbox.name, 'message' => last,
             'url' => "#{ENV.fetch('FRONTEND_URL', nil)}/app/accounts/#{account.id}/conversations/#{conversation.display_id}" }
    AdministratorNotifications::SmartFeaturesMailer.with(account: account).chat_alert(meta).deliver_later
  end
end
