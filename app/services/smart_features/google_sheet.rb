# Smart features > "Google Sheet": new leads, orders and appointments go into the business's own Google Sheet,
# one tab each, and the AI can read a tab named "AI" (Ai::SheetData). The business adds our small Apps Script to the sheet (Extensions > Apps Script) and pastes its
# web app link here, so no Google sign-in or API key is needed. New details get their own column on their own.
class SmartFeatures::GoogleSheet
  URL = %r{\Ahttps://script\.google\.com/macros/s/[\w-]+/exec\z}

  def self.add(account, kind, row)
    return unless account.smart_feature_on?(:google_sheet) && account.smart_feature_on?("sheet_#{kind}")
    return unless account.smart_feature(:sheet_url).match?(URL)

    date = Time.current.in_time_zone(zone(account)).strftime('%Y-%m-%d %H:%M')
    SmartFeatures::GoogleSheetJob.perform_later(account.id, kind.to_s.titleize, { 'Date' => date }.merge(row))
  end

  def self.zone(account)
    account.appointment_setting&.zone || 'Asia/Karachi'
  end

  def self.chat_link(conversation)
    "#{ENV.fetch('FRONTEND_URL', nil)}/app/accounts/#{conversation.account_id}/conversations/#{conversation.display_id}" if conversation
  end

  def self.order(order)
    setting = order.account.catalog_setting || CatalogSetting.new
    items = order.items.map { |item| "#{item['name']} x#{item['quantity']}" }.join(', ')
    add(order.account, :orders, { 'Order' => "##{order.number}", 'Store ref' => order.external_ref, 'Name' => order.customer_name,
                                  'Phone' => order.customer_phone, 'Items' => items, 'Total' => setting.money(order.total),
                                  'Address' => order.address, 'Status' => order.status, 'Taken by' => order.source,
                                  'Chat' => chat_link(order.conversation) })
  end

  def self.appointment(appointment)
    add(appointment.account, :bookings, { 'When' => appointment.label(zone(appointment.account)), 'Name' => appointment.customer_name,
                                          'Phone' => appointment.customer_phone, 'Service' => appointment.service,
                                          'Chat' => chat_link(appointment.conversation) })
  end

  # The script the business pastes into their sheet (shown on the settings page).
  SCRIPT = <<~JS.freeze
    function doPost(e) {
      var data = JSON.parse(e.postData.contents);
      var book = SpreadsheetApp.getActiveSpreadsheet();
      var sheet = book.getSheetByName(data.sheet) || book.insertSheet(data.sheet);
      var headers = sheet.getLastColumn() ? sheet.getRange(1, 1, 1, sheet.getLastColumn()).getValues()[0] : [];
      Object.keys(data.row).forEach(function (key) {
        if (headers.indexOf(key) === -1) { headers.push(key); sheet.getRange(1, headers.length).setValue(key); }
      });
      sheet.appendRow(headers.map(function (key) { return data.row[key] == null ? '' : data.row[key]; }));
      return ContentService.createTextOutput('ok');
    }

    function doGet() {
      var sheet = SpreadsheetApp.getActiveSpreadsheet().getSheetByName('AI');
      var rows = sheet ? sheet.getDataRange().getDisplayValues() : [];
      return ContentService.createTextOutput(JSON.stringify(rows)).setMimeType(ContentService.MimeType.JSON);
    }
  JS
end
