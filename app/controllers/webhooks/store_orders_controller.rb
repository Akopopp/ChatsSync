# Settings > Online store: Shopify and WooCommerce send new orders, shipped orders and (Shopify) checkouts
# to this link. The secret part of the link (made when a store feature is switched on) tells which account it is for.
class Webhooks::StoreOrdersController < ActionController::API
  def create
    token = params[:token].to_s
    account = Account.find_by("smart_features ->> 'cod_token' = ?", token) if token.length >= 32
    return head :not_found if account.blank?

    data = request.request_parameters
    kind = SmartFeatures::StoreOrder.kind(request.headers['X-Shopify-Topic'] || request.headers['X-WC-Webhook-Topic'], data)
    details = case kind
              when :order then SmartFeatures::StoreOrder.parse(data)
              when :shipped then SmartFeatures::StoreOrder.shipment(data)
              when :checkout then SmartFeatures::StoreOrder.checkout(data)
              end
    SmartFeatures::StoreEventJob.perform_later(account.id, kind.to_s, details) if details
    head :ok
  end
end
