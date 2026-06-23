class AddPlanDatesToAccounts < ActiveRecord::Migration[7.0]
  def change
    add_column :accounts, :plan_starts_at, :datetime
    add_column :accounts, :plan_ends_at, :datetime
  end
end
