# Sends one order to Meta as a Purchase (Smart features > "Send sales to Meta").
class SmartFeatures::MetaSaleJob < ApplicationJob
  queue_as :low

  def perform(order_id)
    order = Order.find_by(id: order_id)
    SmartFeatures::MetaSale.new(order: order).perform if order
  end
end
