class AddBookingModeToAppointmentSettings < ActiveRecord::Migration[7.1]
  def change
    # How the AI books on WhatsApp: 'calendar' sends the calendar form inside WhatsApp,
    # 'chat' lets the AI ask the day and time in the chat and book it itself.
    add_column :appointment_settings, :booking_mode, :string, default: 'calendar', null: false
  end
end
