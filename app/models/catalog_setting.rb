# How one account sells through chat: whether the AI uses the product catalog, takes orders,
# the currency, delivery fee, minimum order and notes (delivery time, payment methods).
class CatalogSetting < ApplicationRecord
  class EmptyOrder < StandardError; end
  class BelowMinimum < StandardError; end

  belongs_to :account

  validates :account_id, uniqueness: true
  validates :currency, presence: true, length: { maximum: 10 }
  validates :delivery_fee, :min_order, numericality: { greater_than_or_equal_to: 0 }
  validates :order_notes, length: { maximum: 1000 }

  before_create { self.public_token ||= SecureRandom.alphanumeric(20) }

  def money(amount)
    number = amount.to_d
    text = number.frac.zero? ? number.to_i.to_s : format('%.2f', number)
    "#{currency} #{text.gsub(/\B(?=(\d{3})+(?!\d))/, ',')}"
  end

  # lines: [[product, quantity], ...]. Prices always come from the catalog, never from the chat.
  def place_order!(lines:, source: 'ai', conversation: nil, contact: nil, name: nil, phone: nil, address: nil)
    items = lines.filter_map do |product, quantity|
      next if product.nil? || !product.available || quantity.to_i <= 0

      { 'product_id' => product.id, 'name' => product.name, 'price' => product.price.to_s, 'quantity' => quantity.to_i.clamp(1, 999) }
    end
    raise EmptyOrder if items.empty?

    subtotal = items.sum { |item| item['price'].to_d * item['quantity'] }
    raise BelowMinimum if subtotal < min_order
    with_lock do
      account.orders.create!(
        number: account.orders.maximum(:number).to_i + 1, items: items, subtotal: subtotal, delivery_fee: delivery_fee,
        total: subtotal + delivery_fee, source: source, conversation: conversation, contact: contact, address: address.to_s.strip.presence,
        customer_name: name.to_s.strip.presence || contact&.name, customer_phone: phone.to_s.strip.presence || contact&.phone_number
      )
    end
  end
end
