# Reads a new-order webhook from Shopify ("Order creation") or WooCommerce ("Order created")
# into the few details COD confirmation needs. Returns nil for anything else, like WooCommerce's test ping.
module SmartFeatures::StoreOrder
  module_function

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
