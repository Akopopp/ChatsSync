class AddToneToAiAgents < ActiveRecord::Migration[7.0]
  def change
    add_column :ai_agents, :tone, :string, null: false, default: 'professional'
    add_column :ai_agents, :agent_name, :string
    add_column :ai_agents, :reply_examples, :text
  end
end
