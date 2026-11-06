# Settings > Smart features: on/off switches for ChatsSync extras, plus the health of each WhatsApp number.
class Api::V1::Accounts::SmartFeaturesController < Api::V1::Accounts::BaseController
  before_action :check_admin_authorization?

  def show
    render json: features_json
  end

  def update
    Current.account.update_smart_features!(params.require(:smart_features).permit(*AccountSmartFeatures::SMART_FEATURE_DEFAULTS.keys))
    render json: features_json
  end

  private

  def features_json
    {
      features: Current.account.smart_features_with_defaults,
      numbers: Whatsapp::NumberHealth.for_account(Current.account)
    }
  end
end
