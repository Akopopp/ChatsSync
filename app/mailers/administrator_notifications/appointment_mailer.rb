# Emails the account admins about appointments: each new booking, and the list for today.
class AdministratorNotifications::AppointmentMailer < AdministratorNotifications::BaseMailer
  def new_booking(appointment)
    zone = appointment.account.appointment_setting.zone
    meta = { 'label' => appointment.label(zone), 'name' => appointment.customer_name.to_s, 'phone' => appointment.customer_phone.to_s,
             'source' => { 'ai' => 'the AI agent', 'page' => 'your booking page' }[appointment.source] || 'your team' }
    send_notification("New appointment: #{appointment.label(zone)} – #{appointment.customer_name}",
                      action_url: calendar_url, meta: meta)
  end

  def daily_summary(appointments)
    zone = Current.account.appointment_setting.zone
    lines = appointments.map { |item| "#{item.starts_at.in_time_zone(zone).strftime('%-I:%M %p')} – #{item.customer_name} #{item.service}".strip }
    meta = { 'count' => appointments.size, 'lines' => lines }
    send_notification("Today's appointments: #{appointments.size}", action_url: calendar_url, meta: meta)
  end

  private

  def calendar_url
    "#{ENV.fetch('FRONTEND_URL', nil)}/app/accounts/#{Current.account.id}/appointments"
  end
end
