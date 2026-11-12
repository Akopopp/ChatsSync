# Reads the store webhooks sent to the account's store link (Settings > Online store):
# new orders (COD confirmation), shipped orders (shipping updates) and Shopify checkouts (abandoned carts).
# Returns nil for anything else, like WooCommerce's test ping.
module SmartFeatures::StoreOrder
  module_function

  SHIPPED_TOPICS = %w[orders/fulfilled orders/partially_fulfilled orders/updated order.updated].freeze
  CHECKOUT_TOPICS = %w[checkouts/create checkouts/update].freeze

  # :order, :shipped or :checkout, from the topic header Shopify and WooCommerce send.
  # Older links set up without it are new orders, as before.
  def kind(topic, data)
    return :checkout if CHECKOUT_TOPICS.include?(topic) || (topic.blank? && data.is_a?(Hash) && data.key?('abandoned_checkout_url'))
    return :shipped if SHIPPED_TOPICS.include?(topic)

    :order if topic.blank? || %w[orders/create order.created].include?(topic)
  end

  def parse(data)
    return unless data.is_a?(Hash) && data['line_items'].is_a?(Array)
    return shopify(data) if data.key?('total_price')

    woocommerce(data) if data.key?('billing')
  end

  def shopify(data)
    address = data['shipping_address'] || data['billing_address'] || {}
    customer = data['customer'] || {}
    {
      'ref' => "Shopify #{data['name'] || data['order_number']}",
      'name' => address['name'].presence || [customer['first_name'], customer['last_name']].compact_blank.join(' '),
      'phone' => [address['phone'], data['phone'], customer['phone'], data.dig('billing_address', 'phone')].find(&:present?),
      'address' => [address['address1'], address['address2'], address['city']].compact_blank.join(', '),
      'items' => data['line_items'].map { |item| item(item['title'] || item['name'], item['quantity'], item['price']) },
      'total' => data['total_price'],
      'cod' => Array(data['payment_gateway_names']).join(' ').match?(/cash on delivery|\bcod\b/i) || data['financial_status'] == 'pending'
    }
  end

  def woocommerce(data)
    shipping = data['shipping'] || {}
    billing = data['billing'] || {}
    {
      'ref' => "WooCommerce ##{data['number'] || data['id']}",
      'name' => [billing['first_name'], billing['last_name']].compact_blank.join(' '),
      'phone' => shipping['phone'].presence || billing['phone'],
      'address' => [shipping['address_1'].presence || billing['address_1'], shipping['city'].presence || billing['city']].compact_blank.join(', '),
      'items' => data['line_items'].map { |item| item(item['name'], item['quantity'], item['price']) },
      'total' => data['total'],
      'cod' => data['payment_method'].to_s == 'cod'
    }
  end

  # A shipped Shopify order (with its tracking) or a completed WooCommerce order. nil while nothing is shipped yet.
  def shipment(data)
    order = parse(data)
    return if order.nil?

    if data.key?('total_price')
      fulfillment = Array(data['fulfillments']).reverse.find { |item| item['status'].to_s != 'cancelled' }
      return if fulfillment.nil?

      tracking = { 'courier' => fulfillment['tracking_company'],
                   'tracking_number' => fulfillment['tracking_number'].presence || Array(fulfillment['tracking_numbers']).first,
                   'tracking_url' => fulfillment['tracking_url'].presence || Array(fulfillment['tracking_urls']).first }
    else
      return unless data['status'].to_s == 'completed'

      tracking = woocommerce_tracking(data)
    end
    order.merge(tracking.transform_values { |value| value.to_s.truncate(300).presence })
  end

  # The "Shipment Tracking" plugin's details, when the store uses it.
  def woocommerce_tracking(data)
    meta = Array(data['meta_data']).find { |item| item['key'] == '_wc_shipment_tracking_items' }
    item = Array(meta&.dig('value')).last || {}
    { 'courier' => item['tracking_provider'].presence || item['custom_tracking_provider'], 'tracking_number' => item['tracking_number'],
      'tracking_url' => item['custom_tracking_link'] }
  end

  # A Shopify checkout: who, what and the link back to it. Checkouts without a phone number are skipped.
  def checkout(data)
    return unless data.is_a?(Hash) && data['line_items'].is_a?(Array)

    address = data['shipping_address'] || data['billing_address'] || {}
    customer = data['customer'] || {}
    {
      'token' => (data['token'] || data['id']).to_s,
      'phone' => [data['phone'], address['phone'], customer['phone'], data.dig('billing_address', 'phone')].find(&:present?),
      'name' => address['name'].presence || [customer['first_name'], customer['last_name']].compact_blank.join(' '),
      'items' => data['line_items'].map { |item| item(item['title'] || item['name'], item['quantity'], item['price']) },
      'total' => data['total_price'], 'url' => data['abandoned_checkout_url'], 'completed' => data['completed_at'].present?
    }
  end

  def item(name, quantity, price)
    { 'product_id' => nil, 'name' => name.to_s.truncate(120), 'quantity' => quantity.to_i.clamp(1, 999), 'price' => price.to_d.to_s }
  end

  # "0300 1234567", "92300...", "+92 300..." -> "+923001234567". Pakistani local numbers get +92.
  def phone(value)
    digits = value.to_s.gsub(/\D/, '').delete_prefix('00')
    digits = "92#{digits[1..]}" if digits.start_with?('0')
    "+#{digits}" if digits.length.between?(10, 15)
  end
end
