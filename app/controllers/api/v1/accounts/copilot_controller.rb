class Api::V1::Accounts::CopilotController < Api::V1::Accounts::BaseController

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

  # Stores a picture or video the user attached in Copilot until an action (like saving AI product media) uses it.
  def upload
    file = params.require(:file)
    video = file.content_type.to_s.start_with?('video/')
    return render_upload_error('copilot.image_only') unless video || file.content_type.to_s.start_with?('image/')
    return render_upload_error(video ? 'errors.ai.video_too_big' : 'errors.ai.image_too_big') if file.size > max_upload_size(video)

    blob = ActiveStorage::Blob.create_and_upload!(io: file, filename: file.original_filename, content_type: file.content_type)
    render json: { signed_id: blob.signed_id, filename: blob.filename.to_s }
  end

  private

  def max_upload_size(video)
    video ? AiKnowledgeItem::MAX_VIDEO_SIZE : AiKnowledgeItem::MAX_IMAGE_SIZE
  end

  def render_upload_error(key)
    render json: { error: I18n.t(key) }, status: :unprocessable_entity
  end

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
