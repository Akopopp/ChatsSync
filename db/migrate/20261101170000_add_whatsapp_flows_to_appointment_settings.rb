class AddWhatsappFlowsToAppointmentSettings < ActiveRecord::Migration[7.0]
  def change
    add_column :appointment_settings, :whatsapp_flows, :jsonb, null: false, default: {}
  end
end
