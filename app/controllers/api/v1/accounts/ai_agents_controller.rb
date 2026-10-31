class Api::V1::Accounts::AiAgentsController < Api::V1::Accounts::BaseController
  before_action :check_admin_authorization?
  before_action :fetch_agent

  def show
    render json: agent_json
  end

  def update
    @agent.update!(agent_params)
    render json: agent_json
  end

  # Lets the business try a customer question without sending anything.
  def preview
    question = params.require(:message).to_s.truncate(1000)
    reply = Ai::LlmClient.chat(system: Ai::PromptBuilder.new(agent: @agent).system_prompt(question), messages: [{ role: 'user', text: question }],
                               within: 13)
    render json: { reply: reply }
  rescue Ai::LlmClient::Error => e
    render json: { error: e.message }, status: :service_unavailable
  end

  def generate_faqs
    return render json: { error: I18n.t('errors.ai.business_info_missing') }, status: :unprocessable_entity if @agent.business_info.blank?
    return render_payment_required(I18n.t('errors.ai.copilot_limit')) if Current.account.plan_limit_reached?(:copilot_tasks_monthly)

    items = Ai::FaqGenerator.new(agent: @agent, count: params[:count].presence&.to_i&.clamp(5, 30)).perform
    render json: { created: items.size }
  rescue Ai::LlmClient::Error => e
    render json: { error: e.message }, status: :service_unavailable
  end

  private

  def fetch_agent
    @agent = Current.account.ai_agent || Current.account.create_ai_agent!(business_name: Current.account.name)
  end

  def agent_params
    params.require(:ai_agent).permit(:enabled, :reply_scope, :business_name, :business_info, :instructions, :handoff_message, inbox_ids: [])
  end

  def agent_json
    @agent.as_json(only: %i[enabled reply_scope inbox_ids business_name business_info instructions handoff_message]).merge(
      ai_configured: Ai::LlmClient.configured?,
      features: Plan::FEATURE_KEYS.index_with { |key| Current.account.plan_feature?(key) },
      inboxes: Current.account.inboxes.where(channel_type: AiAgent::CHANNEL_TYPES).map do |inbox|
        { id: inbox.id, name: inbox.name, channel_type: inbox.channel_type }
      end
    )
  end
end
