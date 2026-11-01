# Copilot tools for the product catalog / menu and the orders taken in chat.
class CsCopilot::CatalogTools
  READ_TOOLS = %w[list_products list_orders].freeze
  WRITE_TOOLS = %w[add_products update_product remove_products update_orders update_catalog_settings].freeze
  ADMIN_TOOLS = %w[add_products update_product remove_products update_catalog_settings].freeze

  def self.fn(name, description, properties = {}, required = [])
    { type: 'function', function: { name: name, description: description,
                                     parameters: { type: 'object', properties: properties, required: required } } }
  end

  DATE = { type: 'string', description: 'Date as YYYY-MM-DD (Pakistan time)' }.freeze
  PRODUCT = { type: 'object', properties: {
    name: { type: 'string' }, price: { type: 'number' }, category: { type: 'string' }, description: { type: 'string' },
    image: { type: 'string', description: 'Attached picture, like img1 (optional)' }
  } }.freeze

  DEFINITIONS = [
    fn('list_products', 'List the catalog / menu products with id, price, category and whether they are available.',
       { query: { type: 'string' } }),
    fn('list_orders', 'List orders taken in chat, newest first, with items, total, status and chat.',
       { status: { type: 'string', enum: %w[new confirmed shipped delivered cancelled all] }, from_date: DATE, to_date: DATE }),
    fn('add_products', 'Add products to the catalog / menu, each with a name and price, and optionally a category, ' \
                       'description and an attached picture.', { products: { type: 'array', items: PRODUCT } }, ['products']),
    fn('update_product', 'Change a catalog product: name, price, category, description, or mark it available / sold out.',
       { id: { type: 'integer' }, name: { type: 'string' }, price: { type: 'number' }, category: { type: 'string' },
         description: { type: 'string' }, available: { type: 'boolean' } }, ['id']),
    fn('remove_products', 'Delete catalog products by id.', { ids: { type: 'array', items: { type: 'integer' } } }, ['ids']),
    fn('update_orders', 'Change the status of orders by order number.',
       { numbers: { type: 'array', items: { type: 'integer' } },
         status: { type: 'string', enum: %w[new confirmed shipped delivered cancelled] } }, %w[numbers status]),
    fn('update_catalog_settings', 'Turn the AI catalog on or off, allow AI orders, and set currency, delivery fee, ' \
                                  'minimum order or ordering notes (delivery time, payment methods).',
       { enabled: { type: 'boolean' }, take_orders: { type: 'boolean' }, currency: { type: 'string' },
         delivery_fee: { type: 'number' }, min_order: { type: 'number' }, order_notes: { type: 'string' } })
  ].freeze

  pattr_initialize [:account!, :user!]

  def self.handles?(name)
    (READ_TOOLS + WRITE_TOOLS).include?(name)
  end

  def execute(name, args)
    send("tool_#{name}", args.with_indifferent_access)
  end

  def summary(name, args)
    args = args.with_indifferent_access
    case name
    when 'add_products'
      "Add to the catalog: #{Array(args[:products]).map { |item| "#{item['name']} (#{setting.money(item['price'])})" }.join(', ')}"
    when 'update_product' then "Change product #{product_name(args[:id])}: #{changes_text(args.except(:id))}"
    when 'remove_products' then "Delete #{Array(args[:ids]).size} product(s) from the catalog"
    when 'update_orders' then "Mark order(s) #{Array(args[:numbers]).map { |number| "##{number}" }.join(', ')} as #{args[:status]}"
    when 'update_catalog_settings' then "Change catalog settings: #{changes_text(args)}"
    end
  end

  private

  def setting
    @setting ||= account.catalog_setting || account.create_catalog_setting!
  end

  def tool_list_products(args)
    products = account.products.ordered
    if args[:query].present?
      like = "%#{ActiveRecord::Base.sanitize_sql_like(args[:query])}%"
      products = products.where('name ILIKE ? OR category ILIKE ?', like, like)
    end
    { ai_uses_catalog: setting.enabled, products: products.with_attached_image.limit(100).map do |product|
      { id: product.id, name: product.name, price: setting.money(product.price), category: product.category,
        available: product.available, picture: product.image.attached? }.compact
    end }
  end

  def tool_list_orders(args)
    zone = ActiveSupport::TimeZone[CsCopilot::Tools::TIMEZONE]
    orders = account.orders.order(created_at: :desc).includes(:conversation)
    orders = orders.where(status: args[:status]) if args[:status].present? && args[:status] != 'all'
    orders = orders.where(created_at: zone.parse(args[:from_date])..) if args[:from_date].present?
    orders = orders.where(created_at: ..zone.parse(args[:to_date]).end_of_day) if args[:to_date].present?
    { orders: orders.limit(50).map do |order|
      { number: order.number, customer: order.customer_name, items: order.items.map { |item| "#{item['name']} x#{item['quantity']}" },
        total: setting.money(order.total), status: order.status, address: order.address, chat: order.conversation&.display_id,
        placed: order.created_at.in_time_zone(zone).strftime('%-d %b %-I:%M %p') }.compact
    end }
  end

  def tool_add_products(args)
    errors = Array(args[:products]).filter_map do |item|
      product = account.products.new(name: item['name'], price: item['price'].to_d, category: item['category'], description: item['description'])
      blob = ActiveStorage::Blob.find_signed(item['signed_id'].to_s) if item['signed_id'].present?
      product.image.attach(blob) if blob
      product.save ? nil : "#{item['name']}: #{product.errors.full_messages.to_sentence}"
    end
    { done: true, problems: errors.presence }.compact
  end

  def tool_update_product(args)
    product = account.products.find(args[:id])
    product.update!(args.slice(:name, :price, :category, :description, :available))
    { done: true }
  rescue ActiveRecord::RecordInvalid => e
    raise CsCopilot::Tools::Error, e.record.errors.full_messages.to_sentence
  end

  def tool_remove_products(args)
    { done: true, removed: account.products.where(id: Array(args[:ids])).destroy_all.size }
  end

  def tool_update_orders(args)
    raise CsCopilot::Tools::Error, 'Unknown status.' unless Order::STATUSES.include?(args[:status])

    orders = account.orders.where(number: Array(args[:numbers]))
    orders.each { |order| order.update!(status: args[:status]) }
    { done: true, updated: orders.size }
  end

  def tool_update_catalog_settings(args)
    setting.update!(args.slice(:enabled, :take_orders, :currency, :delivery_fee, :min_order, :order_notes))
    { done: true }
  rescue ActiveRecord::RecordInvalid => e
    raise CsCopilot::Tools::Error, e.record.errors.full_messages.to_sentence
  end

  def changes_text(args)
    args.to_h.map { |key, value| "#{key} = #{value}" }.join(', ')
  end

  def product_name(id)
    account.products.find_by(id: id)&.name || id
  end
end
