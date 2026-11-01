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

  private

  def handlers
    @handlers ||= [
      (Appointments::AiBooking.new(account: account, conversation: conversation) if Appointments::AiBooking.enabled_for?(account))
    ].compact
  end
end
