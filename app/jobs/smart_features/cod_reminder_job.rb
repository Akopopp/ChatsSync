# Smart features > COD > "Ask again if no answer": sends the confirmation template once more.
class SmartFeatures::CodReminderJob < ApplicationJob
  queue_as :low

  def perform(order_id)
    SmartFeatures::CodConfirmation.remind(Order.find_by(id: order_id))
  end
end
