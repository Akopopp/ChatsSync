# Turns one store order into a ChatsSync order and asks the customer to confirm it (Smart features > "COD order confirmation").
class SmartFeatures::CodConfirmationJob < ApplicationJob
  queue_as :default

  def perform(account_id, data)
    account = Account.find_by(id: account_id)
    SmartFeatures::CodConfirmation.new(account: account, data: data).perform if account
  end
end
