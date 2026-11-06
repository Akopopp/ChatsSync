class AddSmartFeaturesToAccounts < ActiveRecord::Migration[7.0]
  def change
    add_column :accounts, :smart_features, :jsonb, null: false, default: {}
  end
end
