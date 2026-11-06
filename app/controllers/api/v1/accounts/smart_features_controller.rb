# Settings > Smart features: on/off switches for ChatsSync extras, plus what the switched-on ones show
# (WhatsApp number health, the ad report and the store link for COD confirmation).
class Api::V1::Accounts::SmartFeaturesController < Api::V1::Accounts::BaseController
  before_action :check_admin_authorization?

  def show
    render json: features_json
  end

  def update
    Current.account.update_smart_features!(params.require(:smart_features).permit(*AccountSmartFeatures.editable_keys))
    render json: features_json
  end

  private

  def features_json
    account = Current.account
    {
      features: account.smart_features_with_defaults.except(*AccountSmartFeatures::SMART_FEATURE_INTERNAL_KEYS),
      numbers: Whatsapp::NumberHealth.for_account(account),
      ads: account.smart_feature_on?(:ad_report) ? SmartFeatures::AdReport.new(account: account).summary : nil,
      cod: account.smart_feature_on?(:cod_confirm) ? SmartFeatures::CodConfirmation.settings_for(account) : nil,
      currency: account.catalog_setting&.currency || 'Rs'
    }
  end
end
