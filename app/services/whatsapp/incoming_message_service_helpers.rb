module Whatsapp::IncomingMessageServiceHelpers
  def download_attachment_file(attachment_payload)
    Down.download(inbox.channel.media_url(attachment_payload[:id]), headers: inbox.channel.api_headers)
  end

  # FEP (Free Entry Point) — QADAM 1: sirf dekhna, kuch badalna nahi.
  #
  # Meta "muft conversation" ke liye alag se koi jhanda nahi bhejta.
  # Uska pata `referral` object se chalta hai, jo SIRF us pehle message
  # ke saath aata hai jo kisi ad (Click-to-WhatsApp) ya FB/IG button se
  # aaya ho. Chatwoot usay bilkul nazarandaaz karta hai.
  #
  # Abhi sirf log kar rahe hain taake ad se aane wale ASLI message par
  # dekh sakein ke referral waqai aata hai aur uski shakl kya hai. Us ke
  # baad hi hara/laal dot wala feature banega — warna andaaza laga kar
  # banate aur pata bhi na chalta ke chala ya nahi.
  def conversation_params
    log_fep_referral

    {
      account_id: @inbox.account_id,
      inbox_id: @inbox.id,
      contact_id: @contact.id,
      contact_inbox_id: @contact_inbox.id
    }
  end

  def log_fep_referral
    msg = messages_data&.first
    return if msg.blank?

    referral = msg[:referral] || msg['referral']
    Rails.logger.info(
      "[CHATSSYNC_FEP] inbox=#{@inbox.id} " \
      "has_referral=#{referral.present?} " \
      "referral=#{referral.inspect} " \
      "msg_keys=#{msg.keys.inspect}"
    )
  rescue StandardError => e
    Rails.logger.info("[CHATSSYNC_FEP] log failed: #{e.message}")
  end

  def processed_params
    @processed_params ||= params
  end

  def account
    @account ||= inbox.account
  end

  def message_type
    messages_data.first[:type]
  end

  def message_content(message)
    # TODO: map interactive messages back to button messages in chatwoot
    message.dig(:text, :body) ||
      message.dig(:button, :text) ||
      message.dig(:interactive, :button_reply, :title) ||
      message.dig(:interactive, :list_reply, :title) ||
      message.dig(:name, :formatted_name)
  end

  def file_content_type(file_type)
    return :image if %w[image sticker].include?(file_type)
    return :audio if %w[audio voice].include?(file_type)
    return :video if ['video'].include?(file_type)
    return :location if ['location'].include?(file_type)
    return :contact if ['contacts'].include?(file_type)

    :file
  end

  def unprocessable_message_type?(message_type)
    %w[reaction ephemeral request_welcome].include?(message_type)
  end

  def processed_waid(waid)
    Whatsapp::PhoneNumberNormalizationService.new(inbox).normalize_and_find_contact_by_provider(waid, :cloud)
  end

  def whatsapp_phone_number(identifier)
    identifier = identifier.to_s
    return if identifier.blank?
    return unless identifier.match?(/\A\d{1,15}\z/)

    identifier
  end

  def error_webhook_event?(message)
    message.key?('errors')
  end

  def log_error(message)
    Rails.logger.warn "Whatsapp Error: #{message['errors'][0]['title']} - contact: #{message['from']}"
  end

  def process_in_reply_to(message)
    @in_reply_to_external_id = message['context']&.[]('id')
  end

  def find_message_by_source_id(source_id)
    return unless source_id

    @message = Message.find_by(source_id: source_id)
  end

  def lock_message_source_id!
    return false if messages_data.blank?

    Whatsapp::MessageDedupLock.new(messages_data.first[:id]).acquire!
  end
end
