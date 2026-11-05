# Reminds customers of their appointment in the same chat they booked in: 3 hours before,
# or earlier if the WhatsApp 24-hour reply window would close before then (messages
# outside that window need a paid template, so they are skipped).
class Appointments::ReminderJob < ApplicationJob
  queue_as :scheduled_jobs

  BEFORE = 3.hours
  WINDOW = 24.hours

  def perform
    Appointment.booked.where(reminded_at: nil, starts_at: Time.current..(Time.current + 48.hours))
               .where(created_at: ...2.hours.ago).where.not(conversation_id: nil)
               .includes(:conversation, account: [:appointment_setting, :ai_agent]).find_each do |appointment|
      remind(appointment) if due?(appointment)
    end
  end

  private

  def due?(appointment)
    account = appointment.account
    return false unless appointment.conversation && account.active? && Appointments::AiBooking.enabled_for?(account)

    last_in = appointment.conversation.messages.incoming.last&.created_at
    appointment.starts_at <= BEFORE.from_now || (last_in.present? && last_in + WINDOW <= 30.minutes.from_now)
  end

  def remind(appointment)
    appointment.update_column(:reminded_at, Time.current) # rubocop:disable Rails/SkipsModelValidations
    conversation = appointment.conversation
    return unless conversation.can_reply?

    conversation.messages.create!(
      account_id: appointment.account_id, inbox_id: conversation.inbox_id, message_type: :outgoing,
      sender: appointment.account.ai_agent&.bot, content: text(appointment, conversation)
    )
  end

  def text(appointment, conversation)
    label = appointment.label(appointment.account.appointment_setting.zone)
    if Ai::PromptBuilder.roman_urdu?(conversation.messages.incoming.last&.content)
      "⏰ Yaad dahani: aap ki appointment #{label} par hai. Time change ya cancel karna ho to yahan bata dein."
    else
      "⏰ Reminder: your appointment is on #{label}. Reply here if you need to change or cancel it."
    end
  end
end
