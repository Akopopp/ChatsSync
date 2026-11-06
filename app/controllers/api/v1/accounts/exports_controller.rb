# "Download CSV" for orders (Settings > Catalog) and appointments (Appointments calendar), to open in Excel or Google Sheets.
class Api::V1::Accounts::ExportsController < Api::V1::Accounts::BaseController
  before_action :check_admin_authorization?

  LIMIT = 20_000

  def show
    case params[:id]
    when 'orders' then render plain: orders_csv, content_type: 'text/csv'
    when 'appointments' then render plain: appointments_csv, content_type: 'text/csv'
    else head :not_found
    end
  end

  private

  def orders_csv
    zone = Current.account.appointment_setting&.zone || ActiveSupport::TimeZone[Plan::TIMEZONE]
    rows = Current.account.orders.order(created_at: :desc).limit(LIMIT).includes(:conversation).map do |order|
      [order.number, order.external_ref, order.created_at.in_time_zone(zone).strftime('%Y-%m-%d %H:%M'), order.status, order.source,
       order.customer_name, order.customer_phone, order.address,
       order.items.map { |item| "#{item['name']} x#{item['quantity']}" }.join(', '),
       order.subtotal, order.delivery_fee, order.total, order.notes, order.conversation&.display_id]
    end
    csv(%w[Order Store\ order Date Status Source Name Phone Address Items Subtotal Delivery Total Notes Chat], rows)
  end

  def appointments_csv
    zone = Current.account.appointment_setting&.zone || ActiveSupport::TimeZone[Plan::TIMEZONE]
    rows = Current.account.appointments.order(starts_at: :desc).limit(LIMIT).includes(:conversation).map do |appointment|
      [appointment.starts_at.in_time_zone(zone).strftime('%Y-%m-%d'), appointment.starts_at.in_time_zone(zone).strftime('%H:%M'),
       appointment.ends_at.in_time_zone(zone).strftime('%H:%M'), appointment.service, appointment.status, appointment.source,
       appointment.customer_name, appointment.customer_phone, appointment.notes, appointment.conversation&.display_id]
    end
    csv(%w[Date Start End Service Status Source Name Phone Notes Chat], rows)
  end

  # CSVSafe stops cells like "=SUM(...)" from running as formulas when the file is opened.
  def csv(headers, rows)
    ([headers] + rows).map { |row| CSVSafe.generate_line(row) }.join
  end
end
