# Settings > WhatsApp forms (admins make the forms), and sending a form from a WhatsApp chat (any agent of that inbox).
# Everything here needs Settings > Smart features > "WhatsApp forms" switched on, except managing the forms themselves.
class Api::V1::Accounts::WhatsappFormsController < Api::V1::Accounts::BaseController
  before_action :check_admin_authorization?, except: [:index, :deliver]
  before_action :fetch_form, except: [:index, :create]

  def index
    forms = Current.account.whatsapp_forms.order(:name)
    return render json: { payload: forms.map { |form| form_json(form) } } if Current.account_user.administrator? && params[:all].present?

    # For the chat: forms the team can send, only when the feature is on.
    forms = Current.account.smart_feature_on?(:whatsapp_forms) ? forms.where(enabled: true) : forms.none
    render json: { payload: forms.map { |form| form.slice(:id, :name, :title) } }
  end

  def create
    render json: form_json(Current.account.whatsapp_forms.create!(form_params))
  end

  def update
    @form.update!(form_params)
    render json: form_json(@form)
  end

  def destroy
    @form.destroy!
    head :ok
  end

  def deliver
    conversation = Current.account.conversations.find_by!(display_id: params[:conversation_id])
    raise Pundit::NotAuthorizedError unless Current.account_user.administrator? || Current.user.assigned_inboxes.include?(conversation.inbox)

    error = deliver_error(conversation)
    return render json: { error: error }, status: :unprocessable_entity if error

    send_form(conversation)
  end

  def responses
    rows = @form.responses.order(created_at: :desc).limit(20_000).includes(:contact).map do |response|
      [response.created_at.in_time_zone(Plan::TIMEZONE).strftime('%Y-%m-%d %H:%M'), response.contact&.name, response.contact&.phone_number] +
        @form.fields.map { |field| response.answers[field['label']] }
    end
    headers = %w[Date Name Phone] + @form.fields.pluck('label')
    render plain: ([headers] + rows).map { |row| CSVSafe.generate_line(row) }.join, content_type: 'text/csv'
  end

  private

  def fetch_form
    @form = Current.account.whatsapp_forms.find(params[:id])
  end

  def deliver_error(conversation)
    return I18n.t('whatsapp_forms.errors.not_enabled') unless Current.account.smart_feature_on?(:whatsapp_forms) && @form.enabled
    return I18n.t('whatsapp_forms.errors.whatsapp_only') unless Appointments::WhatsappFlow.supported?(conversation.inbox)

    I18n.t('whatsapp_forms.errors.window_closed') unless conversation.can_reply?
  end

  # Publishing the form at Meta can fail (missing permission, form check); the reason is shown to the agent.
  def send_form(conversation)
    @form.deliver(conversation, Current.user)
    head :ok
  rescue StandardError => e
    render json: { error: I18n.t('whatsapp_forms.errors.send_failed', error: e.message.truncate(200)) }, status: :unprocessable_entity
  end

  def form_params
    params.require(:whatsapp_form).permit(:name, :title, :intro, :button_label, :submit_label, :enabled,
                                          fields: [:label, :type, :required, :options, { options: [] }])
  end

  def form_json(form)
    form.as_json(only: %i[id name title intro button_label submit_label fields enabled updated_at]).merge(responses_count: form.responses.count)
  end
end
