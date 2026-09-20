class Whatsapp::OneoffCampaignService
  pattr_initialize [:campaign!]

  def perform
    validate_campaign!
    process_audience(extract_audience_labels)
    campaign.completed!
  end

  private

  delegate :inbox, to: :campaign
  delegate :channel, to: :inbox

  def validate_campaign_type!
    raise "Invalid campaign #{campaign.id}" unless whatsapp_campaign? && campaign.one_off?
  end

  def whatsapp_campaign?
    campaign.inbox.inbox_type == 'Whatsapp'
  end

  def validate_campaign_status!
    raise 'Completed Campaign' if campaign.completed?
  end

  def validate_provider!
    raise 'WhatsApp Cloud provider required' if channel.provider != 'whatsapp_cloud'
  end

  def validate_feature_flag!
    raise 'WhatsApp campaigns feature not enabled' unless campaign.account.feature_enabled?(:whatsapp_campaign)
  end

  def validate_campaign!
    validate_campaign_type!
    validate_campaign_status!
    validate_provider!
    validate_feature_flag!
  end

  def extract_audience_labels
    audience_label_ids = campaign.audience.select { |audience| audience['type'] == 'Label' }.pluck('id')
    campaign.account.labels.where(id: audience_label_ids).pluck(:title)
  end

  def process_contact(contact)
    Rails.logger.info "Processing contact: #{contact.name} (#{contact.phone_number})"

    if contact.phone_number.blank?
      Rails.logger.info "Skipping contact #{contact.name} - no phone number"
      return
    end

    if campaign.template_params.blank?
      Rails.logger.error "Skipping contact #{contact.name} - no template_params found for WhatsApp campaign"
      return
    end

    processed_template_params = process_liquid_template_params(contact)
    return if processed_template_params.nil?

    # ===================================================================
    # PAISE BACHANE KA QAIDA
    #
    # Meta template par paise leta hai, magar 24-ghante ki window ke
    # andar aam message MUFT jaata hai.
    #
    # Isliye har contact par alag faisla:
    #   - uski window KHULI hai AUR template sirf text ki hai
    #       -> aam message bhejo (muft), aur woh Chats mein bhi dikhega
    #   - warna
    #       -> pehle ki tarah template (paise lagenge)
    #
    # "Sirf text ki" ka matlab: na header (tasveer/video), na buttons,
    # na {{1}} jaisi jagahein. Warna message adhoora chala jayega.
    #
    # Jis contact ne kabhi message hi nahi kiya, uski window kabhi
    # khuli hi nahi — usay hamesha template jayega.
    #
    # Poora hissa rescue mein hai: kuch bhi ghalat ho to purana raasta
    # chal jaata hai aur campaign nahi rukti.
    # ===================================================================
    return if try_free_text(contact, processed_template_params)

    send_whatsapp_template_message(to: contact.phone_number, template_params: processed_template_params)
  end

  def process_audience(audience_labels)
    contacts = campaign.account.contacts.tagged_with(audience_labels, any: true)
    Rails.logger.info "Processing #{contacts.count} contacts for campaign #{campaign.id}"

    contacts.each { |contact| process_contact(contact) }

    Rails.logger.info "Campaign #{campaign.id} processing completed"
  end

  def process_liquid_template_params(contact)
    liquid_processor = Whatsapp::LiquidTemplateProcessorService.new(campaign: campaign, contact: contact)
    processed_template_params = liquid_processor.process_template_params(campaign.template_params)

    Rails.logger.info "Skipping contact #{contact.name} - liquid variables resolved to blank values" if processed_template_params.nil?

    processed_template_params
  rescue StandardError => e
    Rails.logger.error "Failed to process liquid template params for contact #{contact.name}: #{e.message}"
    nil
  end

  # ---- window khuli ho to muft text ----

  # true lautaye to message ja chuka hai aur template ki zaroorat nahi
  def try_free_text(contact, template_params)
    conversation = open_conversation_for(contact)
    return false if conversation.blank?
    return false unless conversation.can_reply?

    text = plain_text_for(template_params)
    return false if text.blank?

    conversation.messages.create!(
      account_id: campaign.account_id,
      inbox_id: inbox.id,
      message_type: :outgoing,
      content: text,
      additional_attributes: { campaign_id: campaign.id }
    )

    Rails.logger.info(
      "[Campaign #{campaign.id}] FREE text to #{contact.phone_number} (24h window open)"
    )
    true
  rescue StandardError => e
    Rails.logger.error(
      "[Campaign #{campaign.id}] free text failed for #{contact.phone_number}: #{e.message} — template par ja rahe hain"
    )
    false
  end

  def open_conversation_for(contact)
    contact_inbox = ContactInbox.find_by(contact_id: contact.id, inbox_id: inbox.id)
    return nil if contact_inbox.blank?

    contact_inbox.conversations.where.not(status: :resolved).order(:id).last ||
      contact_inbox.conversations.order(:id).last
  rescue StandardError
    nil
  end

  # Template ka BODY text — sirf tab jab template MUKAMMAL text ki ho.
  # Header, buttons, ya {{1}} ho to nil (phir template hi jayega).
  def plain_text_for(template_params)
    tpl = find_template(template_params)
    return nil if tpl.blank?

    components = tpl['components'] || tpl[:components] || []
    return nil if components.blank?

    types = components.map { |c| (c['type'] || c[:type]).to_s.upcase }
    return nil if (types - ['BODY']).any?

    body = components.find { |c| (c['type'] || c[:type]).to_s.upcase == 'BODY' }
    text = (body && (body['text'] || body[:text])).to_s.strip
    return nil if text.blank?
    return nil if text.match?(/\{\{\s*\d+\s*\}\}/)

    text
  rescue StandardError
    nil
  end

  def find_template(template_params)
    name = template_params['name'] || template_params[:name]
    lang = template_params['language'] || template_params[:language] ||
           template_params['lang_code'] || template_params[:lang_code]
    return nil if name.blank?

    list = channel.message_templates || []
    list.find do |t|
      t['name'] == name && (lang.blank? || t['language'] == lang)
    end || list.find { |t| t['name'] == name }
  rescue StandardError
    nil
  end

  # ---- pehle jaisa: template bhejna ----

  def send_whatsapp_template_message(to:, template_params:)
    processor = Whatsapp::TemplateProcessorService.new(
      channel: channel,
      template_params: template_params
    )

    name, namespace, lang_code, processed_parameters = processor.call

    return if name.blank?

    channel.send_template(to, {
                            name: name,
                            namespace: namespace,
                            lang_code: lang_code,
                            parameters: processed_parameters
                          }, nil)
  rescue StandardError => e
    Rails.logger.error "Failed to send WhatsApp template message to #{to}: #{e.message}"
    Rails.logger.error "Backtrace: #{e.backtrace.first(5).join('\n')}"
    # continue processing remaining contacts
    nil
  end
end
