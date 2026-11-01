class CreateAppointments < ActiveRecord::Migration[7.0]
  def change
    create_table :appointment_settings do |t|
      t.bigint :account_id, null: false
      t.boolean :enabled, null: false, default: false
      t.string :timezone, null: false, default: 'Asia/Karachi'
      t.integer :slot_minutes, null: false, default: 30
      t.integer :capacity, null: false, default: 1
      t.integer :days_ahead, null: false, default: 14
      t.integer :min_notice_minutes, null: false, default: 60
      t.jsonb :hours, null: false, default: {}
      t.jsonb :services, null: false, default: []
      t.text :notes
      t.string :public_token
      t.timestamps
    end
    add_index :appointment_settings, :account_id, unique: true
    add_index :appointment_settings, :public_token, unique: true

    create_table :appointments do |t|
      t.bigint :account_id, null: false
      t.bigint :conversation_id
      t.bigint :contact_id
      t.datetime :starts_at, null: false
      t.datetime :ends_at, null: false
      t.string :service
      t.string :customer_name
      t.string :customer_phone
      t.text :notes
      t.string :status, null: false, default: 'booked'
      t.string :source, null: false, default: 'ai'
      t.datetime :reminded_at
      t.timestamps
    end
    add_index :appointments, [:account_id, :starts_at]
    add_index :appointments, :contact_id
  end
end
