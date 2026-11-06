class AddExternalRefToOrders < ActiveRecord::Migration[7.1]
  def change
    # The store's own order number (like "Shopify #1001") for orders sent by Shopify or WooCommerce.
    add_column :orders, :external_ref, :string
    add_index :orders, [:account_id, :external_ref]
  end
end
