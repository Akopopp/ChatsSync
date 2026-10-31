class Api::V1::Accounts::CopilotController < Api::V1::Accounts::BaseController
  def chat
    return render_payment_required(I18n.t('errors.ai.copilot_limit')) if Current.account.plan_limit_reached?(:copilot_tasks_monthly)

    result = agent.run(history_params)
    Current.account.increment_plan_usage!(:copilot_tasks)
    render json: result
  rescue Ai::LlmClient::Error => e
    render json: { error: I18n.t('copilot.unavailable'), detail: e.message.truncate(300) }, status: :service_unavailable
  end

  def confirm
    render json: agent.confirm(params.require(:tool).to_s, params[:args].respond_to?(:to_unsafe_h) ? params[:args].to_unsafe_h : {})
  rescue Copilot::Tools::Error, ActiveRecord::RecordNotFound, ActiveRecord::RecordInvalid => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def agent
    Copilot::Agent.new(account: Current.account, user: Current.user)
  end

  def history_params
    Array(params.require(:messages)).filter_map do |item|
      role = item[:role].to_s
      { role: role, content: item[:content].to_s.truncate(4000) } if %w[user assistant].include?(role) && item[:content].present?
    end
  end
end
