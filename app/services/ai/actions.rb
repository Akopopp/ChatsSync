# Extra things the AI agent can do for an account, like booking appointments or taking orders.
# Each one adds a section to the AI instructions and turns the AI's tags into real records.
class Ai::Actions
  # conversation is nil in the AI preview, where nothing is saved.
  pattr_initialize [:account!, :conversation]

  def prompt_text(question)
    handlers.map { |handler| handler.prompt_text(question) }.join("\n")
  end

  def apply(reply, roman_urdu:)
    handlers.reduce(reply) { |text, handler| handler.apply(text, roman_urdu: roman_urdu) }
  end

  # A form or list to send with the reply (like the WhatsApp booking calendar), from the first handler that has one.
  def interactive
    handlers.lazy.filter_map { |handler| handler.interactive if handler.respond_to?(:interactive) }.first
  end

  def form_requested?
    handlers.any? { |handler| handler.respond_to?(:form_requested?) && handler.form_requested? }
  end

  # Pictures the handlers want sent with the reply (like product pictures from the catalog).
  def media
    handlers.flat_map { |handler| handler.respond_to?(:media) ? handler.media : [] }
  end

  # A handler sends its own messages after the reply (product cards, a chatbot flow box),
  # so the reply counts as an answer even without text.
  def extra_messages?
    handlers.any? { |handler| handler.respond_to?(:extra_messages?) && handler.extra_messages? }
  end

  # Runs after the reply is sent, like sending product cards or the chosen flow box with its buttons.
  def after_send
    handlers.each { |handler| handler.after_send if handler.respond_to?(:after_send) }
  end

  private

  HANDLERS = [Appointments::AiBooking, Catalog::AiOrdering, Ai::OrderStatus, Ai::LeadCapture, Ai::AlertRules, Ai::FlowLink].freeze

  def handlers
    @handlers ||= HANDLERS.filter_map do |handler|
      handler.new(account: account, conversation: conversation) if handler.enabled_for?(account)
    end
  end
end
