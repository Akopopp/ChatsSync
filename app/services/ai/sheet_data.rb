# Smart features > Google Sheet > "AI reads the AI tab": the AI answers from the business's own sheet
# (prices, stock, delivery areas, order status...). The first row is the column names. Read every 10 minutes.
class Ai::SheetData
  MAX_ROWS = 300
  MAX_CHARS = 6000

  pattr_initialize [:account!, :conversation]

  def self.enabled_for?(account)
    account.smart_feature_on?(:google_sheet) && account.smart_feature_on?(:sheet_ai) &&
      account.smart_feature(:sheet_url).match?(SmartFeatures::GoogleSheet::URL)
  end

  def self.rows(account)
    url = account.smart_feature(:sheet_url)
    Rails.cache.fetch("cs:sheet_ai:#{account.id}:#{Digest::MD5.hexdigest(url)}", expires_in: 10.minutes) do
      rows = JSON.parse(HTTParty.get(url, timeout: 10).body)
      rows.is_a?(Array) ? rows.first(MAX_ROWS) : []
    rescue StandardError => e
      Rails.logger.warn("[ChatsSync AI] Google Sheet read failed for account #{account.id}: #{e.message}")
      []
    end
  end

  def prompt_text(_question)
    header, *rows = self.class.rows(account)
    return '' if header.blank? || rows.empty?

    lines = rows.map { |row| header.zip(Array(row)).filter_map { |name, value| "#{name}: #{value}" if value.present? }.join(' | ') }
    <<~TEXT
      Business data from the owner's Google Sheet (up to date; use it for prices, stock, delivery areas and status):
      #{lines.compact_blank.join("\n").truncate(MAX_CHARS)}
    TEXT
  end

  def apply(reply, roman_urdu:) # rubocop:disable Lint/UnusedMethodArgument
    reply
  end
end
