# Online store work that talks to the store's website: importing its products ('products'),
# or marking one order in the store after its status changed here ('order', order_id).
class SmartFeatures::StoreSyncJob < ApplicationJob
  queue_as :low

  def perform(kind, account_id, order_id = nil)
    account = Account.find_by(id: account_id)
    return if account.nil?

    if kind == 'products'
      SmartFeatures::StoreProducts.new(account).perform
    elsif (order = account.orders.find_by(id: order_id))
      SmartFeatures::StoreConnection.new(account).push_status(order)
    end
  rescue SmartFeatures::StoreConnection::Error => e
    Rails.logger.warn("[ChatsSync store] order #{order_id} not marked in the store: #{e.message}")
  end
end
