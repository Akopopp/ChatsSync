# Smart features > "Check payment screenshots": when a customer sends a picture, the AI checks whether it is a
# payment screenshot (JazzCash, Easypaisa, a bank app or deposit slip). If it is, the team gets a private note
# with the amount and transaction ID and the chat gets the "payment-check" label. The customer sees nothing.
class Ai::PaymentCheckJob < ApplicationJob
  queue_as :low

  MAX_IMAGE_BYTES = 4.megabytes
  LABEL = 'payment-check'.freeze
  PROMPT = <<~TEXT.freeze
    You check pictures that customers send to a shop. Decide if this picture is a payment receipt or a money
    transfer screenshot, for example from JazzCash, Easypaisa, SadaPay, NayaPay, a bank app or a bank deposit slip.
    Answer with JSON only and nothing else:
    {"payment": true or false, "amount": "", "transaction_id": "", "date": "", "sender": "", "receiver": "", "app": ""}
    Copy the values exactly as they appear on the receipt. Leave a value empty if it is not shown.
  TEXT
  FIELDS = { 'amount' => 'Amount', 'transaction_id' => 'Transaction ID', 'date' => 'Date', 'sender' => 'From',
             'receiver' => 'To', 'app' => 'Paid with' }.freeze

  def perform(message_id)
    message = Message.find_by(id: message_id)
    account = message&.account
    return unless account&.smart_feature_on?(:payment_check) && Ai::LlmClient.configured?

    image = message.attachments.find { |item| item.image? && item.file.attached? && item.file.byte_size <= MAX_IMAGE_BYTES }
    return if image.nil? || account.plan_limit_reached?('ai_replies_daily')

    receipt = read_receipt(image)
    account.increment_plan_usage!(:ai_replies)
    leave_note(message, receipt) if receipt&.dig('payment') == true
  end

  private

  def read_receipt(image)
    text = Ai::LlmClient.chat(system: PROMPT, messages: [{ role: 'user', text: 'Check this picture.' }],
                              images: [{ mime: image.file.content_type, data: image.file.download }], max_tokens: 250, within: 60)
    JSON.parse(text.to_s[/\{.*\}/m].to_s)
  rescue StandardError => e
    Rails.logger.warn("[ChatsSync AI] payment check failed: #{e.message}")
    nil
  end

  def leave_note(message, receipt)
    conversation = message.conversation
    details = FIELDS.filter_map { |key, label| "#{label}: #{receipt[key]}" if receipt[key].present? }
    content = (['Payment screenshot received. Please check it in your account before confirming the order.'] + details).join("\n")
    conversation.messages.create!(account_id: conversation.account_id, inbox_id: conversation.inbox_id, message_type: :outgoing,
                                  private: true, content: content, sender: AiAgent.find_or_initialize_by(account: conversation.account).bot)
    conversation.add_labels([LABEL])
  end
end
