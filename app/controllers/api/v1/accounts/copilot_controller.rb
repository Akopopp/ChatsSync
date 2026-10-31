class Api::V1::Accounts::CopilotController < Api::V1::Accounts::BaseController
  MAX_UPLOAD_SIZE = 5.megabytes

  def chat
    return render_payment_required(I18n.t('errors.ai.copilot_limit')) if Current.account.plan_limit_reached?(:copilot_tasks_monthly)

    result = agent.run(history_params, uploads_params)
    Current.account.increment_plan_usage!(:copilot_tasks)
    render json: result
  rescue Ai::LlmClient::Error => e
    render json: { error: I18n.t('copilot.unavailable'), detail: e.message.truncate(300) }, status: :service_unavailable
  end

  def confirm
    render json: agent.confirm(params.require(:tool).to_s, params[:args].respond_to?(:to_unsafe_h) ? params[:args].to_unsafe_h : {})
  rescue CsCopilot::Tools::Error, ActiveRecord::RecordNotFound, ActiveRecord::RecordInvalid => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  # Stores a picture the user attached in Copilot until an action (like saving AI product images) uses it.
  def upload
    file = params.require(:file)
    return render json: { error: I18n.t('copilot.image_only') }, status: :unprocessable_entity unless file.content_type.to_s.start_with?('image/')
    return render json: { error: I18n.t('copilot.image_too_big') }, status: :unprocessable_entity if file.size > MAX_UPLOAD_SIZE

    blob = ActiveStorage::Blob.create_and_upload!(io: file, filename: file.original_filename, content_type: file.content_type)
    render json: { signed_id: blob.signed_id, filename: blob.filename.to_s }
  end

  private

  def agent
    CsCopilot::Agent.new(account: Current.account, user: Current.user)
  end

  # { 'img1' => signed blob id } for pictures attached earlier in this Copilot chat
  def uploads_params
    params[:uploads].respond_to?(:to_unsafe_h) ? params[:uploads].to_unsafe_h.transform_values(&:to_s) : {}
  end

  def history_params
    Array(params.require(:messages)).filter_map do |item|
      role = item[:role].to_s
      { role: role, content: item[:content].to_s.truncate(4000) } if %w[user assistant].include?(role) && item[:content].present?
    end
  end
end
