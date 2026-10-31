class CreateAiAgentsAndKnowledge < ActiveRecord::Migration[7.0]
  def change
    create_table :ai_agents do |t|
      t.bigint :account_id, null: false
      t.boolean :enabled, null: false, default: false
      t.string :reply_scope, null: false, default: 'ad_leads'
      t.jsonb :inbox_ids, null: false, default: []
      t.string :business_name
      t.text :business_info
      t.text :instructions
      t.text :handoff_message
      t.timestamps
    end
    add_index :ai_agents, :account_id, unique: true

    create_table :ai_knowledge_items do |t|
      t.bigint :account_id, null: false
      t.string :kind, null: false, default: 'faq'
      t.text :question
      t.text :answer
      t.boolean :enabled, null: false, default: true
      t.timestamps
    end
    add_index :ai_knowledge_items, [:account_id, :kind]
  end
end
