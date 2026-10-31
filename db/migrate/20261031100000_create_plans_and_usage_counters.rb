class CreatePlansAndUsageCounters < ActiveRecord::Migration[7.0]
  def change
    create_table :plans do |t|
      t.string :name, null: false
      t.integer :price, null: false, default: 0
      t.integer :duration_days, null: false, default: 30
      t.jsonb :limits, null: false, default: {}
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :plans, :name, unique: true

    add_column :accounts, :plan_id, :bigint
    add_index :accounts, :plan_id
    add_column :accounts, :plan_addons, :jsonb, null: false, default: {}

    create_table :usage_counters do |t|
      t.bigint :account_id, null: false
      t.string :metric, null: false
      t.string :period, null: false
      t.date :period_start, null: false
      t.integer :count, null: false, default: 0
      t.timestamps
    end
    add_index :usage_counters, [:account_id, :metric, :period, :period_start], unique: true, name: 'index_usage_counters_on_account_metric_period'
  end
end
