# Decides whether the AI should answer a customer's latest messages and sends the reply.
# The AI stays quiet when the rule-based bot is still handling the chat (status pending),
# when a team member replied in the last 12 hours (unless "Turn AI on" was pressed after it), when the chat is locked or handed off,
# when plan limits are used up, and on WhatsApp chats outside Meta's free ad window
# (unless the business turned on replies to all chats and the plan allows it).
class Ai::ReplyService
  HISTORY_LIMIT = 8
  HUMAN_QUIET_PERIOD = 12.hours
  MAX_IMAGE_BYTES = 4.megabytes

  pattr_initialize [:conversation!, :message!]

  def perform
    return unless should_reply?

    turn = customer_turn
    return if turn.empty?

    images = []
    texts = turn.filter_map { |item| message_text(item, images) }
    return if texts.empty? && images.empty?

    question = texts.join("\n").presence || '(customer sent an image)'
    show_typing(turn.last)
    actions = Ai::Actions.new(account: account, conversation: conversation)
    reply = Ai::LlmClient.chat(
      system: prompt_builder.system_prompt(question, first_reply: first_reply?, extra: actions.prompt_text(question),
                                                     earlier: earlier_customer_text(turn)) + earlier_messages(turn),
      messages: [{ role: 'user', text: mask(question) }],
      images: images,
      within: 75
    )
    reply = prompt_builder.tidy(reply, question)
    reply = actions.apply(reply, roman_urdu: roman_urdu_chat?(question, turn)) unless reply.include?(Ai::PromptBuilder::HANDOFF_TAG)
    deliver(reply, turn.last.id, actions.media, actions.interactive)
  end

  private

  def account
    conversation.account
  end

  def agent
    @agent ||= account.ai_agent
  end

  def prompt_builder
    @prompt_builder ||= Ai::PromptBuilder.new(agent: agent)
  end

  def should_reply?
    return false unless agent&.enabled && agent.inbox_allowed?(conversation.inbox)
    return false unless conversation.open?
    return false if conversation.additional_attributes&.dig('plan_locked') || conversation.additional_attributes&.dig('ai_off')
    return false if newer_incoming? || human_replied_recently?
    return false if account.plan_limit_reached?(:ai_replies_monthly) || account.plan_limit_reached?(:ai_replies_daily)

    within_scope?
  end

  def newer_incoming?
    conversation.messages.where(message_type: :incoming).where('id > ?', message.id).exists?
  end

  # "Turn AI on" in the chat ends the quiet period early (ai_resumed_at).
  def human_replied_recently?
    resumed_at = Time.zone.at(conversation.additional_attributes&.dig('ai_resumed_at').to_i)
    conversation.messages.where(message_type: :outgoing, private: false, sender_type: 'User')
                .where('created_at > ?', [HUMAN_QUIET_PERIOD.ago, resumed_at].max).exists?
  end

  def within_scope?
    return true unless conversation.inbox.channel_type == 'Channel::Whatsapp'
    return true if agent.all_chats?

    free_window_open?
  end

  # Meta's free entry point: known end time after our first reply, otherwise 72 hours from the ad click.
  def free_window_open?
    attrs = conversation.additional_attributes || {}
    now = Time.current.to_i
    return attrs['cs_fep_expires_at'].to_i > now if attrs['cs_fep'] && attrs['cs_fep_expires_at'].present?

    attrs['cs_ad_lead'].present? && attrs['cs_ad_lead_at'].to_i > now - 72.hours.to_i
  end

  # The customer's messages since the last reply. An AI reply remembers the last
  # message it answered, so messages that arrived while it was writing still get answered.
  def customer_turn
    replies = conversation.messages.where(message_type: :outgoing, private: false).reorder(id: :desc).limit(20)
    boundary = replies.filter_map { |reply| reply.content_attributes&.dig('ai_answered_up_to')&.to_i || (reply.id if reply.id < message.id) }.max
    conversation.messages.where(message_type: :incoming).where('id > ? AND id <= ?', boundary || 0, message.id).reorder(:id).last(5)
  end

  def message_text(item, images)
    return if item.content == I18n.t('appointments.form.submitted') # the booking form already confirmed it

    parts = [item.content.presence]
    item.attachments.each do |attachment|
      next unless account.plan_feature?(:ai_voice_images)

      if attachment.audio?
        transcript = Ai::Transcriber.transcribe(attachment)
        parts << "(voice note) #{transcript}" if transcript
      elsif attachment.image? && attachment.file.attached? && attachment.file.byte_size <= MAX_IMAGE_BYTES
        images << { mime: attachment.file.content_type, data: attachment.file.download }
        parts << '(customer sent an image)'
      end
    end
    parts.compact.join("\n").presence
  end

  def first_reply?
    !conversation.messages.where(message_type: :outgoing, private: false).exists?
  end

  # On WhatsApp the customer sees their message read and "typing..." while the reply is written.
  def show_typing(customer_message)
    channel = conversation.inbox.channel
    return unless channel.is_a?(Channel::Whatsapp) && channel.provider == 'whatsapp_cloud' && customer_message.source_id.present?

    channel.provider_service.send_typing_indicator(customer_message.source_id)
  rescue StandardError => e
    Rails.logger.warn("[ChatsSync AI] typing indicator failed: #{e.message}")
  end

  # Earlier messages go in as background text rather than as chat turns, so the AI answers
  # the latest message instead of copying or repeating its earlier replies.
  def earlier_messages(turn)
    lines = conversation.messages.where(message_type: %i[incoming outgoing], private: false)
                        .where.not(id: turn.map(&:id)).reorder(id: :desc).limit(HISTORY_LIMIT).to_a.reverse
                        .filter_map { |item| "#{item.incoming? ? 'Customer' : 'You'}: #{mask(item.content.truncate(400))}" if item.content.present? }
    return '' if lines.empty?

    "\nEarlier messages in this chat, oldest first (already answered, for context only):\n#{lines.join("\n")}\n"
  end

  # The customer's messages before this turn, so the AI keeps the language they asked for.
  def earlier_customer_text(turn)
    @earlier_customer_text ||= conversation.messages.where(message_type: :incoming).where.not(id: turn.map(&:id))
                                           .reorder(id: :desc).limit(HISTORY_LIMIT).pluck(:content).compact.reverse.join("\n")
  end

  def roman_urdu_chat?(question, turn)
    prompt_builder.chat_language(question, earlier_customer_text(turn)) == :roman_urdu
  end

  # Customer phone numbers and emails never leave ChatsSync.
  def mask(text)
    text.to_s.gsub(/[\w.+-]+@[\w-]+\.[\w.]+/, '[email]').gsub(/\+?\d[\d\s\-()]{8,}\d/, '[phone]')
  end

  # media: product pictures from the catalog, sent along with any AI product media the reply asks for.
  # interactive: content attributes for a form sent with the text, like the WhatsApp booking calendar.
  def deliver(reply, answered_up_to, media = [], interactive = nil)
    if reply.include?(Ai::PromptBuilder::HANDOFF_TAG)
      hand_off(answered_up_to)
    else
      ids = reply.scan(Ai::PromptBuilder::IMAGE_TAG).flatten.map(&:to_i)
      text = reply.gsub(Ai::PromptBuilder::IMAGE_TAG, '').strip
      items = prompt_builder.image_items(ids) + media
      return if text.blank? && items.empty? && interactive.nil?

      if interactive
        # A form message carries only text, so pictures go first in their own message.
        create_message('', items, answered_up_to) if items.any?
        create_message(text, [], answered_up_to, interactive)
      else
        create_message(text, items, answered_up_to)
      end
    end
    account.increment_plan_usage!(:ai_replies)
  end

  def hand_off(answered_up_to)
    create_message(agent.default_handoff_message, [], answered_up_to)
    conversation.update!(additional_attributes: (conversation.additional_attributes || {}).merge('ai_off' => true))
    conversation.add_labels(['needs-human'])
  end

  def create_message(text, image_items, answered_up_to, interactive = nil)
    reply = conversation.messages.new(
      account_id: account.id, inbox_id: conversation.inbox_id, message_type: :outgoing,
      content: text.presence, sender: agent.bot,
      content_attributes: { 'ai_generated' => true, 'ai_answered_up_to' => answered_up_to }.merge(interactive || {})
    )
    image_items.each { |item| reply.attachments.new(account_id: account.id, file_type: item.video? ? :video : :image, file: item.image.blob) }
    reply.save!
  end
end
