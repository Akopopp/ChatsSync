class AddTriggerValueToAutomationRules < ActiveRecord::Migration[7.1]
  def change
    # For timed automation events: hours for "customer_silent" (like "24"), a time for "daily_time" (like "10:00").
    add_column :automation_rules, :trigger_value, :string
  end
end
