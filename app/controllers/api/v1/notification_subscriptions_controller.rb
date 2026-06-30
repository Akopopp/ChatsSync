class Api::V1::NotificationSubscriptionsController < Api::BaseController
  before_action :set_user

  def create
    notification_subscription = NotificationSubscriptionBuilder.new(user: @user, params: notification_subscription_params).perform
    render json: notification_subscription
  end

  def destroy
    notification_subscription = current_user.notification_subscriptions
                                            .where(["subscription_attributes->>'push_token' = ?", params[:push_token]]).first
    notification_subscription.destroy! if notification_subscription.present?
    head :ok
  end

  private

  def set_user
    @user = current_user
  end

  def notification_subscription_params
    permitted = params.require(:notification_subscription).permit(:identifier, :subscription_type, subscription_attributes: {})
    if permitted[:subscription_type] == 'fcm' && permitted[:identifier].blank?
      token = permitted.dig(:subscription_attributes, :push_token)
      permitted[:identifier] = token if token.present?
    end
    permitted
  end
end
