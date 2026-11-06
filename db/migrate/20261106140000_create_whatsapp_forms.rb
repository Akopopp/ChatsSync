class CreateWhatsappForms < ActiveRecord::Migration[7.1]
  def change
    # Forms that open inside WhatsApp (WhatsApp Flows), made in Settings > WhatsApp forms.
    create_table :whatsapp_forms do |t|
      t.bigint :account_id, null: false
      t.string :name, null: false
      t.string :title, null: false
      t.text :intro
      t.string :button_label, null: false, default: 'Fill the form'
      t.string :submit_label, null: false, default: 'Submit'
      t.jsonb :fields, null: false, default: []
      t.jsonb :flows, null: false, default: {}
      t.boolean :enabled, null: false, default: true
      t.timestamps
    end
    add_index :whatsapp_forms, :account_id

    create_table :whatsapp_form_responses do |t|
      t.bigint :account_id, null: false
      t.bigint :whatsapp_form_id, null: false
      t.bigint :conversation_id
      t.bigint :contact_id
      t.jsonb :answers, null: false, default: {}
      t.timestamps
    end
    add_index :whatsapp_form_responses, [:whatsapp_form_id, :created_at]
  end
end
