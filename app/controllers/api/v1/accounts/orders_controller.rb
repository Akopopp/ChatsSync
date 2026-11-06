class Api::V1::Accounts::OrdersController < Api::V1::Accounts::BaseController
  before_action :fetch_order, only: [:update]

  def index
    orders = Current.account.orders.order(created_at: :desc).includes(:conversation)
    orders = orders.where(status: params[:status]) if params[:status].present?
    render json: { payload: orders.limit(200).map { |order| order_json(order) } }
  end

  def update
    @order.update!(params.require(:order).permit(:status, :notes))
    render json: order_json(@order)
  end

  private

  def fetch_order
    @order = Current.account.orders.find(params[:id])
  end

  def order_json(order)
    order.as_json(only: %i[id number customer_name customer_phone address items subtotal delivery_fee total status source notes external_ref
                           created_at])
         .merge(conversation_id: order.conversation&.display_id)
  end
end
