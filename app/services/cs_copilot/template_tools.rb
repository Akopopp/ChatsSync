# Copilot tools for WhatsApp templates and campaigns, like "make an order confirmation template"
# or "send the eid_offer template to everyone with the label vip tomorrow at 5 pm".
class CsCopilot::TemplateTools
  READ_TOOLS = %w[list_templates list_campaigns].freeze
  WRITE_TOOLS = %w[create_template create_campaign].freeze
  ADMIN_TOOLS = WRITE_TOOLS

  def self.fn(name, description, properties = {}, required = [])
    { type: 'function', function: { name: name, description: description,
                                     parameters: { type: 'object', properties: properties, required: required } } }
  end

  TEXTS = { type: 'array', items: { type: 'string' } }.freeze

  DEFINITIONS = [
    fn('list_templates', 'List WhatsApp templates of the WhatsApp numbers with their status (APPROVED, PENDING, REJECTED) and text.',
       { inbox_id: { type: 'integer' } }),
    fn('create_template', 'Send a new WhatsApp template to Meta for review. Body may use {{1}}, {{2}} for the customer\'s name etc.; ' \
                          'then give one example per variable. Category MARKETING for offers, UTILITY for orders and updates.',
       { inbox_id: { type: 'integer' }, name: { type: 'string', description: 'lowercase_with_underscores' },
         category: { type: 'string', description: 'MARKETING or UTILITY' }, language: { type: 'string', description: 'en, ur or en_US' },
         body: { type: 'string' }, examples: TEXTS, footer: { type: 'string' },
         buttons: { type: 'array', description: 'Up to 3 quick reply button texts', items: { type: 'string' } } },
       %w[inbox_id name category body]),
    fn('list_campaigns', 'List WhatsApp campaigns with their template, audience labels, time and status.'),
    fn('create_campaign', 'Schedule a WhatsApp campaign: an APPROVED template sent to every contact with the given labels. ' \
                          'values fill {{1}}, {{2}} in order and may use {{contact.name}}.',
       { title: { type: 'string' }, inbox_id: { type: 'integer' }, template: { type: 'string' },
         labels: TEXTS, values: TEXTS, send_at: { type: 'string', description: 'YYYY-MM-DD HH:MM Pakistan time; empty = now' } },
       %w[title inbox_id template labels])
  ].freeze

  pattr_initialize [:account!, :user!]

  def self.handles?(name)
    (READ_TOOLS + WRITE_TOOLS).include?(name)
  end

  def execute(name, args)
    send("tool_#{name}", args.with_indifferent_access)
  end

  def summary(name, args)
    args = args.with_indifferent_access
    case name
    when 'create_template' then "Send template \"#{args[:name]}\" (#{args[:category]}) to WhatsApp for review: #{args[:body].to_s.truncate(120)}"
    when 'create_campaign'
      "Send template \"#{args[:template]}\" to contacts labelled #{Array(args[:labels]).join(', ')} " \
        "#{args[:send_at].present? ? "at #{args[:send_at]}" : 'now'} (campaign \"#{args[:title]}\")"
    end
  end

  private

  def whatsapp_inboxes
    account.inboxes.where(channel_type: 'Channel::Whatsapp')
  end

  def whatsapp_inbox(id)
    whatsapp_inboxes.find_by(id: id) || raise(CsCopilot::Tools::Error, 'Pick one of the WhatsApp numbers (inbox_id).')
  end

  def body_text(template)
    Array(template['components']).find { |component| component['type'] == 'BODY' }&.dig('text')
  end

  def tool_list_templates(args)
    inboxes = args[:inbox_id].present? ? [whatsapp_inbox(args[:inbox_id])] : whatsapp_inboxes
    inboxes.map do |inbox|
      templates = Array(inbox.channel.message_templates).first(60).map do |template|
        { name: template['name'], status: template['status'], category: template['category'], language: template['language'],
          text: body_text(template).to_s.truncate(160) }
      end
      { inbox_id: inbox.id, number: inbox.name, templates: templates }
    end
  end

  def tool_create_template(args)
    inbox = whatsapp_inbox(args[:inbox_id])
    body = { account_id: account.id, inbox_id: inbox.id, name: args[:name], category: args[:category].to_s.upcase,
             language: args[:language].presence || 'en', body_text: args[:body], footer_text: args[:footer].presence,
             buttons: Array(args[:buttons]).first(3).map { |text| { type: 'QUICK_REPLY', text: text } } }
    body[:body_example] = Array(args[:examples]) if args[:examples].present?
    result = bot_request(body)
    raise CsCopilot::Tools::Error, result['error'].to_s.presence || 'WhatsApp did not accept the template.' unless result['ok']

    { done: true, status: 'sent to WhatsApp for review', page: 'Templates' }
  end

  def tool_list_campaigns(_args)
    account.campaigns.where(inbox_id: whatsapp_inboxes.select(:id)).order(id: :desc).limit(30).map do |campaign|
      { id: campaign.display_id, title: campaign.title, template: campaign.template_params&.dig('name'),
        labels: account.labels.where(id: Array(campaign.audience).pluck('id')).pluck(:title),
        send_at: campaign.scheduled_at&.in_time_zone(CsCopilot::Tools::TIMEZONE)&.strftime('%Y-%m-%d %H:%M'), status: campaign.campaign_status }
    end
  end

  def tool_create_campaign(args)
    inbox = whatsapp_inbox(args[:inbox_id])
    template = approved_template(inbox, args[:template])
    labels = audience_labels(args[:labels])
    values = Array(args[:values]).each_with_index.to_h { |value, index| [(index + 1).to_s, value] }
    campaign = account.campaigns.create!(title: args[:title], inbox: inbox, message: fill(body_text(template), values),
                                         template_params: template_params(template, values),
                                         audience: labels.map { |label| { id: label.id, type: 'Label' } }, scheduled_at: send_time(args[:send_at]))
    { done: true, id: campaign.display_id, contacts_with_labels: labels.pluck(:title), page: 'Campaigns > WhatsApp' }
  rescue ActiveRecord::RecordInvalid => e
    raise CsCopilot::Tools::Error, e.record.errors.full_messages.to_sentence
  end

  def approved_template(inbox, name)
    template = Array(inbox.channel.message_templates).find { |item| item['name'] == name && item['status'] == 'APPROVED' }
    template || raise(CsCopilot::Tools::Error, "No approved template named #{name} on this number.")
  end

  def audience_labels(names)
    labels = account.labels.where(title: Array(names))
    labels.presence || raise(CsCopilot::Tools::Error, 'Pick at least one existing label for the contacts.')
  end

  def template_params(template, values)
    { name: template['name'], namespace: template['namespace'].to_s, category: template['category'], language: template['language'],
      processed_params: values.present? ? { body: values } : {} }
  end

  def fill(text, values)
    text.to_s.gsub(/\{\{(\d+)\}\}/) { values[Regexp.last_match(1)] || Regexp.last_match(0) }
  end

  def send_time(value)
    return Time.current if value.blank?

    Time.find_zone(CsCopilot::Tools::TIMEZONE).parse(value) || raise(CsCopilot::Tools::Error, 'Write the time as YYYY-MM-DD HH:MM.')
  end

  def bot_request(body)
    base = ENV.fetch('CHATSSYNC_BOT_URL', '').chomp('/')
    raise CsCopilot::Tools::Error, 'Templates are not connected on this server yet.' if base.blank?

    headers = { 'X-CS-Token' => user.access_token&.token.to_s, 'X-CS-Account' => account.id.to_s, 'Content-Type' => 'application/json' }
    response = HTTParty.post("#{base}/api/templates", body: body.to_json, headers: headers, timeout: 25)
    response.parsed_response.is_a?(Hash) ? response.parsed_response : {}
  end
end
