class Api::V1::Accounts::AiKnowledgeItemsController < Api::V1::Accounts::BaseController
  before_action :check_admin_authorization?
  before_action :fetch_item, only: %i[update destroy]

  def index
    items = Current.account.ai_knowledge_items.with_attached_image.order(id: :desc)
    render json: items.map { |item| item_json(item) }
  end

  def create
    item = Current.account.ai_knowledge_items.new(item_params)
    item.image.attach(params[:image]) if params[:image].present?
    item.save!
    render json: item_json(item)
  end

  def update
    @item.update!(item_params)
    render json: item_json(@item)
  end

  def destroy
    @item.destroy!
    head :ok
  end

  private

  def fetch_item
    @item = Current.account.ai_knowledge_items.find(params[:id])
  end

  def item_params
    params.permit(:kind, :question, :answer, :enabled)
  end

  def item_json(item)
    item.as_json(only: %i[id kind question answer enabled]).merge(image_url: item.image_url, video: item.video?)
  end
end
