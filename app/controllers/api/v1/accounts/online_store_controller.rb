# Settings > Online store > "Your store": the store's website and API key (SmartFeatures::StoreConnection),
# and importing the store's products into the catalog (SmartFeatures::StoreProducts, in the background).
class Api::V1::Accounts::OnlineStoreController < Api::V1::Accounts::BaseController
  before_action :check_admin_authorization?

  def show
    render json: connection.settings
  end

  def update
    connection.update!(params.permit(:platform, :url, :token, :secret, :remove_key).to_h.symbolize_keys)
    render json: connection.settings
  end

  def import_products
    return render json: { error: I18n.t('online_store.no_url') }, status: :unprocessable_entity if connection.data['url'].blank?

    SmartFeatures::StoreSyncJob.perform_later('products', Current.account.id)
    head :accepted
  end

  private

  def connection
    @connection ||= SmartFeatures::StoreConnection.new(Current.account)
  end
end
