# Settings > Online store > "Import products": copies the store's products into the catalog, so the AI can
# answer about them and send their pictures. Uses the store's public product list, so no key is needed:
# Shopify's /products.json and WooCommerce's Store API. Products with the same name are updated, not repeated.
class SmartFeatures::StoreProducts
  MAX_PRODUCTS = 300
  MAX_PAGES = 5

  pattr_initialize :account

  # Returns how many products were added or updated.
  def perform
    connection = SmartFeatures::StoreConnection.new(account)
    url = connection.data['url']
    return 0 if url.blank?

    items = connection.data['platform'] == 'woocommerce' ? woocommerce(url) : shopify(url)
    count = items.first(MAX_PRODUCTS).count { |item| save(item) }
    connection.save(connection.data.merge('imported_at' => Time.current.iso8601, 'imported' => count))
    count
  end

  private

  def shopify(url)
    (1..MAX_PAGES).each_with_object([]) do |page, all|
      list = Array(fetch("#{url}/products.json?limit=250&page=#{page}")&.dig('products'))
      all.concat(list.map { |product| shopify_item(product) })
      break all if list.size < 250
    end
  end

  def shopify_item(product)
    variant = Array(product['variants']).first || {}
    { name: product['title'], description: product['body_html'], price: variant['price'], category: product['product_type'],
      available: Array(product['variants']).any? { |item| item['available'] != false },
      image: Array(product['images']).first&.dig('src') }
  end

  def woocommerce(url)
    (1..MAX_PAGES).each_with_object([]) do |page, all|
      list = Array(fetch("#{url}/wp-json/wc/store/v1/products?per_page=100&page=#{page}"))
      all.concat(list.map { |product| woocommerce_item(product) })
      break all if list.size < 100
    end
  end

  # Store API prices are in the smallest unit ("350000" with 2 decimals is 3500.00).
  def woocommerce_item(product)
    prices = product['prices'] || {}
    price = prices['price'].to_d / (10**prices['currency_minor_unit'].to_i)
    { name: product['name'], description: product['short_description'].presence || product['description'], price: price,
      category: Array(product['categories']).first&.dig('name'), available: product['is_in_stock'] != false,
      image: Array(product['images']).first&.dig('src') }
  end

  def fetch(url)
    response = HTTParty.get(url, timeout: 20, headers: { 'Accept' => 'application/json' })
    response.success? ? response.parsed_response : nil
  rescue StandardError => e
    Rails.logger.warn("[ChatsSync store] product import failed: #{e.message}")
    nil
  end

  def save(item)
    name = text(item[:name]).truncate(120)
    return false if name.blank?

    product = account.products.find_or_initialize_by(name: name)
    product.assign_attributes(description: text(item[:description]).truncate(1000).presence, price: item[:price].to_d.clamp(0, 10**9),
                              category: text(item[:category]).truncate(60).presence, available: item[:available])
    attach_image(product, item[:image]) unless product.image.attached?
    product.save
  rescue StandardError => e
    Rails.logger.warn("[ChatsSync store] product #{name} skipped: #{e.message}")
    false
  end

  def text(value)
    ActionController::Base.helpers.strip_tags(value.to_s).gsub(/\s+/, ' ').strip
  end

  def attach_image(product, url)
    return unless url.to_s.start_with?('https://')

    response = HTTParty.get(url, timeout: 20)
    type = response.headers['content-type'].to_s
    return unless response.success? && type.start_with?('image/') && response.body.bytesize <= Product::MAX_IMAGE_SIZE

    product.image.attach(io: StringIO.new(response.body), filename: File.basename(URI.parse(url).path).presence || 'product.jpg',
                         content_type: type)
  end
end
