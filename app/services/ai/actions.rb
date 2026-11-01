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

  # Pictures the handlers want sent with the reply (like product pictures from the catalog).
  def media
    handlers.flat_map { |handler| handler.respond_to?(:media) ? handler.media : [] }
  end

  private

  def handlers
    @handlers ||= [Appointments::AiBooking, Catalog::AiOrdering].filter_map do |handler|
      handler.new(account: account, conversation: conversation) if handler.enabled_for?(account)
    end
  end
end
