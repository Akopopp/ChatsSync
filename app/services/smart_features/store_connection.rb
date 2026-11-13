# Settings > Online store > "Your store": the store's website (to import its products into the catalog) and,
# optionally, the store's API key so ChatsSync marks orders in the store when their status changes here
# (a COD order confirmed or cancelled on WhatsApp, or the team changing the status in Orders).
# Kept in the account's internal attributes; the key and secret are never sent back to the browser.
class SmartFeatures::StoreConnection
  PLATFORMS = %w[shopify woocommerce].freeze
  BLOCKED_HOSTS = /\A(localhost|.*\.local|.*\.internal|\d+\.\d+\.\d+\.\d+|\[.*\])\z/i
  SHOPIFY_API = '2025-01'.freeze
  # What each status adds to the order in the store (a Shopify tag or a WooCommerce order note).
  STATUS_NOTES = { 'confirmed' => 'WhatsApp confirmed', 'cancelled' => 'WhatsApp cancelled', 'shipped' => 'WhatsApp shipped',
                   'delivered' => 'WhatsApp delivered' }.freeze

  class Error < StandardError; end

  pattr_initialize :account

  def settings
    { platform: data['platform'], url: data['url'], key_saved: data['token'].present?, imported_at: data['imported_at'],
      imported: data['imported'] }
  end

  def update!(params)
    store = data.merge('platform' => PLATFORMS.include?(params[:platform]) ? params[:platform] : data['platform'],
                       'url' => params.key?(:url) ? self.class.clean_url(params[:url]) : data['url'])
    store['token'] = params[:token].to_s.strip.first(200) if params[:token].present?
    store['secret'] = params[:secret].to_s.strip.first(200) if params[:secret].present?
    store = store.except('token', 'secret') if ActiveModel::Type::Boolean.new.cast(params[:remove_key])
    save(store)
  end

  def data
    (account.internal_attributes || {})['store'] || {}
  end

  def save(store)
    account.update!(internal_attributes: (account.internal_attributes || {}).merge('store' => store))
  end

  def can_update_orders?
    data['url'].present? && data['token'].present? && (data['platform'] == 'shopify' || data['secret'].present?)
  end

  # "mystore.com/shop/" -> "https://mystore.com"; only public https websites.
  def self.clean_url(value)
    uri = URI.parse(value.to_s.strip.then { |url| url.match?(%r{\Ahttps?://}i) ? url : "https://#{url}" })
    return '' if uri.host.blank? || uri.host.match?(BLOCKED_HOSTS) || !uri.host.include?('.')

    "https://#{uri.host.downcase}"
  rescue URI::InvalidURIError
    ''
  end

  # Marks the order in the store: a Shopify tag, or a WooCommerce note (and "cancelled" for a cancelled order).
  def push_status(order)
    note = STATUS_NOTES[order.status]
    return if note.nil? || order.store_order_id.blank? || !can_update_orders?

    data['platform'] == 'shopify' ? shopify_tag(order.store_order_id, note) : woocommerce_note(order, note)
  end

  private

  def shopify_tag(order_id, tag)
    query = 'mutation($id: ID!, $tags: [String!]!) { tagsAdd(id: $id, tags: $tags) { userErrors { message } } }'
    body = { query: query, variables: { id: "gid://shopify/Order/#{order_id}", tags: [tag] } }
    headers = { 'X-Shopify-Access-Token' => data['token'], 'Content-Type' => 'application/json' }
    response = HTTParty.post("#{data['url']}/admin/api/#{SHOPIFY_API}/graphql.json", headers: headers, body: body.to_json, timeout: 15)
    raise Error, "Shopify #{response.code}" unless response.success?
  end

  def woocommerce_note(order, note)
    auth = { username: data['token'], password: data['secret'] }
    base = "#{data['url']}/wp-json/wc/v3/orders/#{order.store_order_id}"
    if order.status == 'cancelled'
      response = HTTParty.put(base, basic_auth: auth, timeout: 15, headers: { 'Content-Type' => 'application/json' },
                                    body: { status: 'cancelled' }.to_json)
      raise Error, "WooCommerce #{response.code}" unless response.success?
    end
    response = HTTParty.post("#{base}/notes", basic_auth: auth, timeout: 15, headers: { 'Content-Type' => 'application/json' },
                                              body: { note: note }.to_json)
    raise Error, "WooCommerce #{response.code}" unless response.success?
  end
end
