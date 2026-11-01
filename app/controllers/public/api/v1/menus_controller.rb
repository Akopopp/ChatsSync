# The public menu / catalog page of one account.
class Public::Api::V1::MenusController < PublicController
  def show
    setting = CatalogSetting.find_by!(public_token: params[:token])
    account = setting.account
    raise ActiveRecord::RecordNotFound unless account.active? && setting.enabled && account.plan_feature?(:catalog_orders)

    products = account.products.available.with_attached_image.ordered.limit(500)
    render json: {
      business_name: account.ai_agent&.business_name.presence || account.name,
      notes: setting.order_notes,
      whatsapp: whatsapp_number(account),
      products: products.map do |product|
        { id: product.id, name: product.name, description: product.description, category: product.category.presence,
          price: setting.money(product.price), image_url: product.image_url }
      end
    }
  end

  private

  def whatsapp_number(account)
    channel = account.inboxes.where(channel_type: 'Channel::Whatsapp').first&.channel
    channel&.phone_number.to_s.gsub(/\D/, '').presence
  end
end
