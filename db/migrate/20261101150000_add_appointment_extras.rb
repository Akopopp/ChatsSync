class AddAppointmentExtras < ActiveRecord::Migration[7.0]
  def change
    add_column :appointment_settings, :closed_dates, :jsonb, null: false, default: []
    add_column :appointment_settings, :ics_token, :string
    add_index :appointment_settings, :ics_token, unique: true
    add_column :appointments, :manage_token, :string
    add_index :appointments, :manage_token, unique: true
  end
end
