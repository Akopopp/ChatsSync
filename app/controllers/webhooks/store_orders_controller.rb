# Smart features > "COD order confirmation": Shopify and WooCommerce send each new order to this link.
# The secret part of the link (made when the feature is switched on) tells which account the order is for.
class Webhooks::StoreOrdersController < ActionController::API
  def create
    token = params[:token].to_s
    account = Account.find_by("smart_features ->> 'cod_token' = ?", token) if token.length >= 32
    return head :not_found if account.blank?

    order = SmartFeatures::StoreOrder.parse(request.request_parameters)
    SmartFeatures::CodConfirmationJob.perform_later(account.id, order) if order && account.smart_feature_on?(:cod_confirm)
    head :ok
  end
end
