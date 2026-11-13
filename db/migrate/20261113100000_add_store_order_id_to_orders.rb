class AddStoreOrderIdToOrders < ActiveRecord::Migration[7.1]
  def change
    # The order's id in Shopify or WooCommerce, so ChatsSync can mark the order in the store (confirmed, cancelled...).
    add_column :orders, :store_order_id, :string
  end
end
