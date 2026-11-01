# What the AI agent knows and does with the product catalog in one chat: it gets the products
# and prices in its instructions, sends product pictures with [PRODUCT:id], and its [ORDER:...]
# tag becomes a real order here, priced from the catalog (never from the chat).
class Catalog::AiOrdering
  PRODUCT_TAG = /\[PRODUCT:\s*(\d+)\s*\]/i
  ORDER_TAG = /\[ORDER:\s*([^\]|]+)\|?([^\]|]*)\|?([^\]]*)\]/i
  QUANTITY = /[x×*]\s*(\d+)/i
  MAX_PRODUCTS = 60
  MAX_PICTURES = 4
  NO_ORDERS = "- Do not take orders in chat; tell the customer how to order using the business information.\n".freeze

  # conversation is nil in the AI preview, where nothing is saved.
  pattr_initialize [:account!, :conversation]

  def self.enabled_for?(account)
    setting = account.catalog_setting
    setting&.enabled && account.plan_feature?(:catalog_orders) && account.products.available.exists?
  end

  def setting
    @setting ||= account.catalog_setting
  end

  # Product pictures the reply should send.
  def media
    @media ||= []
  end

  def prompt_text(question)
    lines = relevant_products(question).map do |product|
      ["##{product.id} #{product.name} – #{setting.money(product.price)}", product.category.presence,
       ('has picture' if product.image.attached?), product.description.to_s.squish.truncate(120).presence].compact.join(' | ')
    end
    <<~TEXT
      Catalog and ordering (prices in #{setting.currency}):
      #{lines.join("\n")}
      - Only quote products and prices from this catalog. If something is not in it, say it is not available.
      - To show a product picture, put [PRODUCT:<id>] on its own line (at most #{MAX_PICTURES}, only products that have a picture).
      #{setting.take_orders ? order_rules : NO_ORDERS}#{page_text}
    TEXT
  end

  # Turns the tags in the AI reply into product pictures and an order. Returns the reply text to send.
  def apply(reply, roman_urdu:)
    ids = reply.scan(PRODUCT_TAG).flatten.map(&:to_i)
    pictures = account.products.available.with_attached_image.where(id: ids).select { |product| product.image.attached? }
    media.concat(pictures.first(MAX_PICTURES))
    text = reply.gsub(PRODUCT_TAG, '')
    match = text.match(ORDER_TAG)
    return text.strip if match.nil? || !setting.take_orders

    [text.gsub(ORDER_TAG, '').strip, order(match[1], match[2], match[3], roman_urdu: roman_urdu)].compact_blank.join("\n")
  end

  private

  def order_rules
    rules = +"- To take an order, find out the items and quantities, the customer's name and the delivery address. " \
             "Then repeat the items and ask the customer to confirm.\n" \
             "- Only after the customer confirms, write one short thank-you line and put " \
             "[ORDER:<id> x <quantity>, <id> x <quantity>|Customer name|Delivery address] on its own line. " \
             "Do not write the total yourself: the system adds the order summary with the total.\n"
    rules << "- Delivery fee: #{setting.money(setting.delivery_fee)}.\n" if setting.delivery_fee.positive?
    rules << "- Minimum order: #{setting.money(setting.min_order)}.\n" if setting.min_order.positive?
    rules << "- Ordering notes from the business: #{setting.order_notes.squish}\n" if setting.order_notes.present?
    rules << "- If the customer wants to change or cancel an order they already placed, reply with #{Ai::PromptBuilder::HANDOFF_TAG}.\n"
    rules
  end

  def page_text
    url = Catalog::PublicLink.url(setting)
    url ? "- If the customer wants to see the full menu or catalog with pictures, send this link: #{url}\n" : ''
  end

  # Small catalogs go in whole; big ones send the products whose words match the question first.
  def relevant_products(question)
    products = account.products.available.with_attached_image.ordered.limit(500).to_a
    return products if products.size <= MAX_PRODUCTS

    words = question.to_s.downcase.scan(/[[:alnum:]]{3,}/)
    products.sort_by { |product| -words.count { |word| "#{product.name} #{product.category}".downcase.include?(word) } }
            .first(MAX_PRODUCTS)
  end

  def order(items_text, name, address, roman_urdu:)
    lines = items_text.split(/[,;]/).filter_map do |part|
      id = part[/\d+/] or next
      [account.products.find_by(id: id), (part[QUANTITY, 1] || 1).to_i]
    end
    return "(Preview: would place an order for #{lines.map { |product, quantity| "#{product&.name} x#{quantity}" }.join(', ')})" if conversation.nil?

    placed = setting.place_order!(lines: lines, conversation: conversation, contact: conversation.contact, name: name, address: address)
    tell_team(placed)
    heading = roman_urdu ? "✅ Order ##{placed.number} confirm ho gaya:" : "✅ Order ##{placed.number} confirmed:"
    "#{heading}\n#{placed.summary(setting)}"
  rescue CatalogSetting::EmptyOrder
    roman_urdu ? 'Maazrat, ye items abhi available nahi hain.' : 'Sorry, those items are not available right now.'
  rescue CatalogSetting::BelowMinimum
    roman_urdu ? "Minimum order #{setting.money(setting.min_order)} hai." : "The minimum order is #{setting.money(setting.min_order)}."
  end

  def tell_team(placed)
    conversation.add_labels(['order'])
    conversation.messages.create!(
      account_id: account.id, inbox_id: conversation.inbox_id, message_type: :activity,
      content: "Order ##{placed.number} placed by AI: #{setting.money(placed.total)} – #{placed.customer_name}"
    )
  end
end
