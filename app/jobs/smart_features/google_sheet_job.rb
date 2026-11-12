# Adds one row to the business's Google Sheet (Smart features > "Google Sheet").
class SmartFeatures::GoogleSheetJob < ApplicationJob
  queue_as :low
  retry_on Net::OpenTimeout, Net::ReadTimeout, wait: 1.minute, attempts: 3

  def perform(account_id, sheet, row)
    url = Account.find_by(id: account_id)&.smart_feature(:sheet_url)
    return unless url.to_s.match?(SmartFeatures::GoogleSheet::URL)

    # Google answers with a redirect once the row is added; there is nothing to follow.
    HTTParty.post(url, body: { sheet: sheet, row: row.compact_blank }.to_json, headers: { 'Content-Type' => 'application/json' },
                       follow_redirects: false, timeout: 20)
  end
end
