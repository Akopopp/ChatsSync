# One store webhook (Settings > Online store): a new order, a shipped order or a Shopify checkout.
class SmartFeatures::StoreEventJob < ApplicationJob
  queue_as :default

  def perform(account_id, kind, data)
    account = Account.find_by(id: account_id)
    return if account.nil?

    updates = SmartFeatures::StoreUpdates.new(account: account)
    case kind
    when 'order'
      updates.ordered(SmartFeatures::StoreOrder.phone(data['phone']))
      SmartFeatures::CodConfirmation.new(account: account, data: data).perform
    when 'shipped' then updates.shipped(data)
    when 'checkout' then updates.checkout(data)
    end
  end
end
