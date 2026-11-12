# Smart features > "Send from other apps": the secret link other apps post to. See SmartFeatures::AppMessage.
class Webhooks::AppMessagesController < ActionController::API
  PER_MINUTE = 60

  def create
    token = params[:token].to_s
    account = Account.find_by("smart_features ->> 'app_token' = ?", token) if token.length >= 32
    return head :not_found unless account&.smart_feature_on?(:app_webhook)
    return render json: { ok: false, error: 'Too many messages. Try again in a minute.' }, status: :too_many_requests unless within_limit?(account)

    result = SmartFeatures::AppMessage.new(account: account, params: message_params).perform
    render json: result, status: result[:ok] ? :ok : :unprocessable_entity
  end

  private

  def message_params
    params.permit(:phone, :name, :text, :template, :label, values: []).to_h.stringify_keys
  end

  def within_limit?(account)
    key = "cs:app_webhook:#{account.id}:#{Time.current.strftime('%Y%m%d%H%M')}"
    count = Redis::Alfred.incr(key)
    Redis::Alfred.expire(key, 120) if count == 1
    count <= PER_MINUTE
  end
end
