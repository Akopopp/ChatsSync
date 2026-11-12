class AddFlowSettingsToAiAgents < ActiveRecord::Migration[7.1]
  def change
    # use_flows: the AI and the chatbot flow answer the same chat, and the AI can send a flow box.
    # max_replies_per_chat: after this many AI replies in a row the chat goes to the team (0 = no limit).
    add_column :ai_agents, :use_flows, :boolean, default: false, null: false
    add_column :ai_agents, :max_replies_per_chat, :integer, default: 0, null: false
  end
end
