class Api::V1::Accounts::ProductsController < Api::V1::Accounts::BaseController
  before_action :check_admin_authorization?, except: [:index]
  before_action :fetch_product, only: %i[update destroy]

  def index
    render json: Current.account.products.with_attached_image.ordered.map { |product| product_json(product) }
  end

  def create
    product = Current.account.products.new(product_params)
    product.image.attach(params[:image]) if params[:image].present?
    product.save!
    render json: product_json(product)
  end

  def update
    @product.image.attach(params[:image]) if params[:image].present?
    @product.update!(product_params)
    render json: product_json(@product)
  end

  def destroy
    @product.destroy!
    head :ok
  end

  private

  def fetch_product
    @product = Current.account.products.find(params[:id])
  end

  def product_params
    params.permit(:name, :description, :price, :category, :available, :position)
  end

  def product_json(product)
    price = product.price.frac.zero? ? product.price.to_i : product.price.to_f
    product.as_json(only: %i[id name description category available position]).merge(price: price, image_url: product.image_url)
  end
end
