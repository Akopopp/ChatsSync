class CreateCatalog < ActiveRecord::Migration[7.0]
  def change
    create_table :catalog_settings do |t|
      t.bigint :account_id, null: false
      t.boolean :enabled, null: false, default: false
      t.boolean :take_orders, null: false, default: true
      t.string :currency, null: false, default: 'Rs'
      t.decimal :delivery_fee, precision: 12, scale: 2, null: false, default: 0
      t.decimal :min_order, precision: 12, scale: 2, null: false, default: 0
      t.text :order_notes
      t.string :public_token
      t.timestamps
    end
    add_index :catalog_settings, :account_id, unique: true
    add_index :catalog_settings, :public_token, unique: true

    create_table :products do |t|
      t.bigint :account_id, null: false
      t.string :name, null: false
      t.text :description
      t.decimal :price, precision: 12, scale: 2, null: false, default: 0
      t.string :category
      t.boolean :available, null: false, default: true
      t.integer :position, null: false, default: 0
      t.timestamps
    end
    add_index :products, [:account_id, :category]

    create_table :orders do |t|
      t.bigint :account_id, null: false
      t.integer :number, null: false
      t.bigint :conversation_id
      t.bigint :contact_id
      t.string :customer_name
      t.string :customer_phone
      t.text :address
      t.jsonb :items, null: false, default: []
      t.decimal :subtotal, :delivery_fee, :total, precision: 12, scale: 2, null: false, default: 0
      t.string :status, null: false, default: 'new'
      t.string :source, null: false, default: 'ai'
      t.text :notes
      t.timestamps
    end
    add_index :orders, [:account_id, :number], unique: true
    add_index :orders, [:account_id, :created_at]
    add_index :orders, :contact_id
  end
end
