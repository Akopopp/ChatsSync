class Api::V1::Accounts::CatalogSettingsController < Api::V1::Accounts::BaseController
  before_action :check_admin_authorization?
  before_action :fetch_setting

  def show
    render json: setting_json
  end

  def update
    @setting.update!(params.require(:catalog_setting).permit(:enabled, :take_orders, :currency, :delivery_fee, :min_order, :order_notes))
    render json: setting_json
  end

  private

  def fetch_setting
    @setting = Current.account.catalog_setting || Current.account.create_catalog_setting!
  end

  def setting_json
    @setting.as_json(only: %i[enabled take_orders currency order_notes]).merge(
      delivery_fee: plain(@setting.delivery_fee), min_order: plain(@setting.min_order),
      menu_page_url: Catalog::PublicLink.url(@setting),
      feature_available: Current.account.plan_feature?(:catalog_orders)
    )
  end

  def plain(amount)
    amount.frac.zero? ? amount.to_i : amount.to_f
  end
end
