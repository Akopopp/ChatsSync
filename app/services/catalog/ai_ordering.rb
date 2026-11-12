# What the AI agent knows and does with the product catalog in one chat: it gets the products
# and prices in its instructions, shows products with [PRODUCT:id], and its [ORDER:...]
# tag becomes a real order here, priced from the catalog (never from the chat).
# On WhatsApp each product shown is its own card, like a WhatsApp Business catalog item:
# picture, name, price and details, with an "Order now" button when the business takes orders.
class Catalog::AiOrdering
  PRODUCT_TAG = /\[PRODUCT:\s*(\d+)\s*\]/i
  TOTAL_TAG = /\[TOTAL:\s*([^\]]+)\]/i
  ORDER_TAG = /\[ORDER:\s*([^\]|]+)\|?([^\]|]*)\|?([^\]]*)\]/i
  QUANTITY = /[x×*]\s*(\d+)/i
  MAX_PRODUCTS = 60
  MAX_PICTURES = 4
  ORDER_BUTTON = '🛒 Order now'.freeze
  PICTURE_RULE = 'These products have no pictures yet; if asked for pictures, say they are not available in chat right now.'.freeze
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

  # WhatsApp product cards, sent after the reply text.
  def cards
    @cards ||= []
  end

  def extra_messages?
    cards.any?
  end

  def after_send
    cards.each { |product| send_card(product) }
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
      - The numbers after # are internal ids. Never write them or a # to the customer.
      - Never add up prices yourself. To tell a total, write [TOTAL:<id> x <quantity>, <id> x <quantity>] in your sentence
        where the amount goes; the system replaces it with the exact total#{' including delivery' if setting.delivery_fee.positive?}.
      #{setting.take_orders ? order_rules : NO_ORDERS}#{show_rules}
    TEXT
  end

  # Turns the tags in the AI reply into product pictures and an order. Returns the reply text to send.
  def apply(reply, roman_urdu:)
    text = show_products(reply, roman_urdu: roman_urdu).gsub(TOTAL_TAG) { total_text(Regexp.last_match(1)) }
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

  # The AI only writes [PRODUCT:id]; the name, price, details, picture and the catalog link are put in here,
  # so the customer always gets the real product in the chat and never a bare link or a made-up price.
  def show_rules
    "- To show a product, put [PRODUCT:<id>] on its own line. The system replaces it with the product's name, price, " \
      "details and picture, so do not type those yourself.\n" \
      "- If the customer asks to see products, pictures, the catalog or the menu, show up to #{MAX_PICTURES} matching products " \
      "this way and ask which one they like. Never send a link instead and never say you cannot show products here.\n" \
      "- Never say you sent a picture. #{PICTURE_RULE unless pictures?}\n" \
      "- You are already chatting with the customer here. Never say the business is not available on WhatsApp or in this chat.\n"
  end

  def pictures?
    account.products.available.joins(:image_attachment).exists?
  end

  def show_products(reply, roman_urdu:)
    ids = reply.scan(PRODUCT_TAG).flatten.map(&:to_i).uniq
    shown = account.products.available.with_attached_image.where(id: ids).index_by(&:id)
    if whatsapp_cards?
      cards.concat(ids.filter_map { |id| shown[id] }.first(MAX_PICTURES))
      text = reply.gsub(PRODUCT_TAG, '')
    else
      media.concat(shown.values.select { |product| product.image.attached? }.first(MAX_PICTURES))
      text = reply.gsub(PRODUCT_TAG) { "\n#{product_card(shown[Regexp.last_match(1).to_i])}\n" }
    end
    text = text.gsub(/^#\d+\s+/, '').gsub(/\n{3,}/, "\n\n")
    url = Catalog::PublicLink.url(setting)
    return text if shown.empty? || url.nil?

    "#{text.strip}\n\n#{roman_urdu ? 'Poora catalog' : 'Full catalog'}: #{url}"
  end

  def product_card(product)
    return '' if product.nil?

    ["*#{product.name}* – #{setting.money(product.price)}", product.description.to_s.squish.truncate(160).presence].compact.join("\n")
  end

  def whatsapp_cards?
    channel = conversation&.inbox&.channel
    channel.is_a?(Channel::Whatsapp) && channel.provider == 'whatsapp_cloud'
  end

  # The card's button tap comes back as a reply to this message, so the AI knows which product it is.
  def send_card(product)
    card = conversation.messages.new(
      account_id: account.id, inbox_id: conversation.inbox_id, message_type: :outgoing, sender: account.ai_agent.bot,
      content: product_card(product), content_attributes: { 'ai_generated' => true, 'product_id' => product.id }
    )
    if setting.take_orders
      card.content_type = :input_select
      card.content_attributes['items'] = [{ 'title' => ORDER_BUTTON, 'value' => "order_product_#{product.id}" }]
    end
    card.attachments.new(account_id: account.id, file_type: :image, file: product.image.blob) if product.image.attached?
    card.save!
  end

  # Small catalogs go in whole; big ones send the products whose words match the question first.
  def relevant_products(question)
    products = account.products.available.with_attached_image.ordered.limit(500).to_a
    return products if products.size <= MAX_PRODUCTS

    words = question.to_s.downcase.scan(/[[:alnum:]]{3,}/)
    products.sort_by { |product| -words.count { |word| "#{product.name} #{product.category}".downcase.include?(word) } }
            .first(MAX_PRODUCTS)
  end

  def order_lines(items_text)
    items_text.split(/[,;]/).filter_map do |part|
      id = part[/\d+/] or next
      [account.products.find_by(id: id), (part[QUANTITY, 1] || 1).to_i]
    end
  end

  def total_text(items_text)
    subtotal = order_lines(items_text).sum { |product, quantity| product&.available ? product.price * quantity.clamp(0, 999) : 0 }
    return setting.money(subtotal) unless setting.delivery_fee.positive?

    "#{setting.money(subtotal + setting.delivery_fee)} (#{setting.money(subtotal)} + #{setting.money(setting.delivery_fee)} delivery)"
  end

  def order(items_text, name, address, roman_urdu:)
    lines = order_lines(items_text)
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
