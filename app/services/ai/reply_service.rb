# Decides whether the AI should answer a customer's latest messages and sends the reply.
# The AI stays quiet when the rule-based bot is still handling the chat (status pending),
# when a team member replied in the last 12 hours, when the chat is locked or handed off,
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
    reply = Ai::LlmClient.chat(
      system: prompt_builder.system_prompt(question),
      messages: history(turn) + [{ role: 'user', text: mask(question) }],
      images: images,
      within: 75
    )
    deliver(reply, turn.last.id)
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

  def human_replied_recently?
    conversation.messages.where(message_type: :outgoing, private: false, sender_type: 'User')
                .where('created_at > ?', HUMAN_QUIET_PERIOD.ago).exists?
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
    replies = conversation.messages.where(message_type: :outgoing, private: false).order(id: :desc).limit(20)
    boundary = replies.filter_map { |reply| reply.content_attributes&.dig('ai_answered_up_to')&.to_i || (reply.id if reply.id < message.id) }.max
    conversation.messages.where(message_type: :incoming).where('id > ? AND id <= ?', boundary || 0, message.id).order(:id).last(5)
  end

  def message_text(item, images)
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

  def history(turn)
    conversation.messages.where(message_type: %i[incoming outgoing], private: false)
                .where.not(id: turn.map(&:id)).order(id: :desc).limit(HISTORY_LIMIT).to_a.reverse
                .filter_map do |item|
      next if item.content.blank?

      { role: item.incoming? ? 'user' : 'assistant', text: mask(item.content.truncate(400)) }
    end
  end

  # Customer phone numbers and emails never leave ChatsSync.
  def mask(text)
    text.to_s.gsub(/[\w.+-]+@[\w-]+\.[\w.]+/, '[email]').gsub(/\+?\d[\d\s\-()]{8,}\d/, '[phone]')
  end

  def deliver(reply, answered_up_to)
    if reply.include?(Ai::PromptBuilder::HANDOFF_TAG)
      hand_off(answered_up_to)
    else
      ids = reply.scan(Ai::PromptBuilder::IMAGE_TAG).flatten.map(&:to_i)
      text = reply.gsub(Ai::PromptBuilder::IMAGE_TAG, '').strip
      return if text.blank? && ids.empty?

      create_message(text, prompt_builder.image_items(ids), answered_up_to)
    end
    account.increment_plan_usage!(:ai_replies)
  end

  def hand_off(answered_up_to)
    create_message(agent.default_handoff_message, [], answered_up_to)
    conversation.update!(additional_attributes: (conversation.additional_attributes || {}).merge('ai_off' => true))
    conversation.add_labels(['needs-human'])
  end

  def create_message(text, image_items, answered_up_to)
    reply = conversation.messages.new(
      account_id: account.id, inbox_id: conversation.inbox_id, message_type: :outgoing,
      content: text.presence, sender: agent.bot,
      content_attributes: { 'ai_generated' => true, 'ai_answered_up_to' => answered_up_to }
    )
    image_items.each { |item| reply.attachments.new(account_id: account.id, file_type: :image, file: item.image.blob) }
    reply.save!
  end
end
