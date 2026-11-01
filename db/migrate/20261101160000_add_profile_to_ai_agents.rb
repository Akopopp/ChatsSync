class AddProfileToAiAgents < ActiveRecord::Migration[7.0]
  def change
    add_column :ai_agents, :policies, :jsonb, null: false, default: {}
    add_column :ai_agents, :always_rules, :text
    add_column :ai_agents, :never_rules, :text
    add_column :ai_agents, :handoff_rules, :text
    add_column :ai_agents, :goal, :string, null: false, default: 'answer'
    add_column :ai_agents, :lead_fields, :string
    add_column :ai_agents, :reply_length, :string, null: false, default: 'short'
    add_column :ai_agents, :use_emoji, :boolean, null: false, default: false
    add_column :ai_agents, :reply_language, :string, null: false, default: 'match'
  end
end
