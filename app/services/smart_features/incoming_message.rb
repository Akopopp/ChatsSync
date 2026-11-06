# Smart features that react to a customer's message; each one runs only when switched on in Settings > Smart features.
module SmartFeatures::IncomingMessage
  module_function

  def run(message)
    account = message.account
    Ai::PaymentCheckJob.set(wait: 5.seconds).perform_later(message.id) if account.smart_feature_on?(:payment_check) && message.attachments.any?
    Whatsapp::StopOptOut.new(message: message).perform if account.smart_feature_on?(:stop_opt_out)
    SmartFeatures::ReviewRequest.handle_answer(message) if account.smart_feature_on?(:review_request)
    SmartFeatures::CodConfirmation.handle_answer(message) if account.smart_feature_on?(:cod_confirm)
  end

  # Messages already answered by a smart feature, so the AI stays out of them.
  def answered?(message)
    attrs = message.conversation.additional_attributes || {}
    (message.account.smart_feature_on?(:stop_opt_out) && Whatsapp::StopOptOut.keyword?(message.content)) ||
      [SmartFeatures::ReviewRequest::ANSWER_KEY, SmartFeatures::CodConfirmation::ANSWER_KEY].any? { |key| attrs[key] == message.id }
  end
end
