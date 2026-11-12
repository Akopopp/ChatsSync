# Smart features > "Abandoned cart reminder": checks one Shopify checkout after the chosen hours.
class SmartFeatures::CartReminderJob < ApplicationJob
  queue_as :low

  def perform(account_id, token)
    account = Account.find_by(id: account_id)
    SmartFeatures::StoreUpdates.new(account: account).remind(token) if account
  end
end
