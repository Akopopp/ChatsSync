# Everything the Copilot can look up or do in ChatsSync, with the same permissions as the signed-in user.
# Read tools run straight away; write tools are only proposed and run after the user confirms.
class CsCopilot::Tools # rubocop:disable Metrics/ClassLength
  class Error < StandardError; end

  TIMEZONE = 'Asia/Karachi'.freeze
  WRITE_TOOLS = %w[add_labels assign_conversation change_status add_private_note send_reply
                   create_canned_response create_label add_faqs add_product_images update_ai_agent].freeze
  ADMIN_TOOLS = %w[create_canned_response create_label add_faqs add_product_images update_ai_agent].freeze

  def self.fn(name, description, properties = {}, required = [])
    { type: 'function', function: { name: name, description: description,
                                     parameters: { type: 'object', properties: properties, required: required } } }
  end

  DATE = { type: 'string', description: 'Date as YYYY-MM-DD (Pakistan time)' }.freeze
  CHAT = { type: 'integer', description: 'Chat number shown as #number' }.freeze

  DEFINITIONS = [
    fn('search_conversations', 'Find chats. Filter by words in messages or contact name/phone, status, label, inbox, agent and dates.',
       { query: { type: 'string' }, status: { type: 'string', enum: %w[open resolved pending snoozed all] },
         label: { type: 'string' }, inbox_id: { type: 'integer' }, assignee_id: { type: 'integer' },
         from_date: DATE, to_date: DATE, limit: { type: 'integer' } }),
    fn('get_conversation', 'Read the latest messages of one chat, with who sent each message.', { conversation_id: CHAT }, ['conversation_id']),
    fn('search_contacts', 'Find contacts by name, phone or email.', { query: { type: 'string' } }, ['query']),
    fn('message_stats', 'Count messages in a date range: received, and sent by each team member, by ChatsSync AI, by the chatbot/flows and others.',
       { from_date: DATE, to_date: DATE, inbox_id: { type: 'integer' } }),
    fn('agent_activity', 'Per team member: messages sent and chats resolved in a date range.', { from_date: DATE, to_date: DATE }),
    fn('list_team', 'List team members (agents and admins), teams, inboxes and labels with their ids.'),
    fn('list_canned_responses', 'List saved canned responses.'),
    fn('plan_usage', 'Show the ChatsSync plan, end date and how much of each limit is used.'),
    fn('ai_settings', 'Show the AI agent settings and how many FAQs and images it has.'),
    fn('add_labels', 'Add labels to a chat.', { conversation_id: CHAT, labels: { type: 'array', items: { type: 'string' } } },
       %w[conversation_id labels]),
    fn('assign_conversation', 'Assign a chat to a team member and/or a team.',
       { conversation_id: CHAT, agent_id: { type: 'integer' }, team_id: { type: 'integer' } }, ['conversation_id']),
    fn('change_status', 'Open, resolve or mark a chat pending.',
       { conversation_id: CHAT, status: { type: 'string', enum: %w[open resolved pending] } },
       %w[conversation_id status]),
    fn('add_private_note', 'Add a private note to a chat (customers do not see it).', { conversation_id: CHAT, text: { type: 'string' } },
       %w[conversation_id text]),
    fn('send_reply', 'Send a message to the customer in a chat.', { conversation_id: CHAT, text: { type: 'string' } }, %w[conversation_id text]),
    fn('create_canned_response', 'Save a canned response.', { short_code: { type: 'string' }, content: { type: 'string' } }, %w[short_code content]),
    fn('create_label', 'Create a new label.',
       { title: { type: 'string' }, color: { type: 'string', description: 'Hex color like #1f93ff' } }, ['title']),
    fn('add_faqs', 'Add FAQs to the AI agent. Put several ways of asking in one question, separated by " / ".',
       { faqs: { type: 'array', items: { type: 'object', properties: { question: { type: 'string' }, answer: { type: 'string' } } } } }, ['faqs']),
    fn('add_product_images', 'Save pictures or videos the user attached as AI product media, so the AI can send them to customers.',
       { images: { type: 'array', items: { type: 'object', properties: {
         image: { type: 'string', description: 'Attached picture or video, like img1' },
         name: { type: 'string', description: 'Product name' },
         details: { type: 'string', description: 'Price and details' }
       } } } }, ['images']),
    fn('update_ai_agent', 'Change AI agent settings.',
       { enabled: { type: 'boolean' }, reply_scope: { type: 'string', enum: %w[ad_leads all] },
         business_info_to_add: { type: 'string', description: 'Text to add at the end of the business information' },
         instructions: { type: 'string' }, handoff_message: { type: 'string' } })
  ].freeze

  pattr_initialize [:account!, :user!]

  def write?(name)
    WRITE_TOOLS.include?(name)
  end

  def execute(name, args)
    raise Error, "Unknown tool #{name}" unless DEFINITIONS.any? { |tool| tool[:function][:name] == name }
    raise Error, 'Only administrators can do this.' if ADMIN_TOOLS.include?(name) && !admin?

    send("tool_#{name}", args.with_indifferent_access)
  end

  def summary(name, args)
    args = args.with_indifferent_access
    case name
    when 'add_labels' then "Add labels #{Array(args[:labels]).join(', ')} to chat ##{args[:conversation_id]}"
    when 'assign_conversation' then "Assign chat ##{args[:conversation_id]}#{" to #{agent_name(args[:agent_id])}" if args[:agent_id]}" \
                                    "#{" (team #{args[:team_id]})" if args[:team_id]}"
    when 'change_status' then "Mark chat ##{args[:conversation_id]} as #{args[:status]}"
    when 'add_private_note' then "Add a private note to chat ##{args[:conversation_id]}: \"#{args[:text].to_s.truncate(120)}\""
    when 'send_reply' then "Send to the customer in chat ##{args[:conversation_id]}: \"#{args[:text].to_s.truncate(200)}\""
    when 'create_canned_response' then "Save canned response /#{args[:short_code]}"
    when 'create_label' then "Create label \"#{args[:title]}\""
    when 'add_faqs' then "Add #{Array(args[:faqs]).size} FAQs to the AI agent"
    when 'add_product_images' then "Save #{Array(args[:images]).size} product pictures/videos for the AI: " \
                                   "#{Array(args[:images]).pluck('name').compact.join(', ')}"
    when 'update_ai_agent' then "Change AI settings: #{args.except(:business_info_to_add).keys.join(', ')}" \
                                "#{' and add business info' if args[:business_info_to_add].present?}"
    else name.humanize
    end
  end

  # Swaps the picture names the model uses (img1) for the stored uploads, so confirming saves the right files.
  def with_uploads(name, args, uploads)
    return args unless name == 'add_product_images'

    args.merge('images' => Array(args['images']).map { |item| item.to_h.merge('signed_id' => uploads[item.to_h['image'].to_s]) })
  end

  private

  def admin?
    account.account_users.find_by(user_id: user.id)&.administrator?
  end

  def conversations
    account.conversations.where(inbox_id: user.assigned_inboxes.select(:id))
  end

  def conversation(display_id)
    conversations.find_by(display_id: display_id) || raise(Error, "Chat ##{display_id} not found or you do not have access to it.")
  end

  def range(args, default_days: 7)
    zone = ActiveSupport::TimeZone[TIMEZONE]
    from = args[:from_date].present? ? zone.parse(args[:from_date]).beginning_of_day : default_days.days.ago.in_time_zone(zone).beginning_of_day
    to = args[:to_date].present? ? zone.parse(args[:to_date]).end_of_day : Time.current
    from..to
  end

  # Only the last 4 digits of phone numbers go to the AI provider.
  def short_phone(phone)
    phone.present? ? "****#{phone.to_s.last(4)}" : nil
  end

  def time(value)
    value&.in_time_zone(TIMEZONE)&.strftime('%d %b %Y %I:%M %p')
  end

  def agent_name(id)
    account.users.find_by(id: id)&.name || "member #{id}"
  end

  def sender_label(message)
    return 'Customer' if message.incoming?
    return 'AI' if message.content_attributes&.dig('ai_generated')

    case message.sender_type
    when 'User' then message.sender&.name || 'Team member'
    when 'AgentBot' then 'Chatbot'
    else 'System'
    end
  end

  def tool_search_conversations(args)
    scope = conversations.includes(:contact, :assignee, :inbox).order(last_activity_at: :desc)
    scope = scope.where(status: args[:status]) if args[:status].present? && args[:status] != 'all'
    scope = scope.where(inbox_id: args[:inbox_id]) if args[:inbox_id].present?
    scope = scope.where(assignee_id: args[:assignee_id]) if args[:assignee_id].present?
    scope = scope.tagged_with(args[:label]) if args[:label].present?
    scope = scope.where(last_activity_at: range(args, default_days: 3650)) if args[:from_date].present? || args[:to_date].present?
    if args[:query].present?
      like = "%#{ActiveRecord::Base.sanitize_sql_like(args[:query])}%"
      in_messages = account.messages.where('content ILIKE ?', like).select(:conversation_id)
      in_contacts = account.contacts.where('name ILIKE ? OR phone_number ILIKE ? OR email ILIKE ?', like, like, like).select(:id)
      scope = scope.where(id: in_messages).or(scope.where(contact_id: in_contacts))
    end
    rows = scope.limit((args[:limit] || 15).to_i.clamp(1, 30)).map do |chat|
      last = chat.messages.where(private: false).reorder(:id).last
      { chat: chat.display_id, contact: chat.contact&.name, phone: short_phone(chat.contact&.phone_number), status: chat.status,
        inbox: chat.inbox&.name, assignee: chat.assignee&.name, labels: chat.label_list,
        last_message: last && "#{sender_label(last)}: #{last.content.to_s.truncate(120)}", last_activity: time(chat.last_activity_at) }
    end
    { count: rows.size, chats: rows }
  end

  def tool_get_conversation(args)
    chat = conversation(args[:conversation_id])
    messages = chat.messages.where(message_type: %i[incoming outgoing]).reorder(id: :desc).limit(30).to_a.reverse
    { chat: chat.display_id, contact: chat.contact&.name, phone: short_phone(chat.contact&.phone_number), status: chat.status,
      assignee: chat.assignee&.name, labels: chat.label_list,
      messages: messages.map do |message|
        { at: time(message.created_at), from: sender_label(message), private: message.private, text: message.content.to_s.truncate(300),
          attachments: message.attachments.map(&:file_type).presence }.compact
      end }
  end

  def tool_search_contacts(args)
    like = "%#{ActiveRecord::Base.sanitize_sql_like(args[:query].to_s)}%"
    contacts = account.contacts.where('name ILIKE ? OR phone_number ILIKE ? OR email ILIKE ?', like, like, like)
                      .order(last_activity_at: :desc).limit(15)
    { contacts: contacts.map do |contact|
      chats = conversations.where(contact_id: contact.id).order(last_activity_at: :desc).limit(3).pluck(:display_id)
      { name: contact.name, phone: short_phone(contact.phone_number), last_seen: time(contact.last_activity_at), chats: chats }
    end }
  end

  def tool_message_stats(args)
    period = range(args)
    scope = account.messages.where(created_at: period, private: false, inbox_id: user.assigned_inboxes.select(:id))
    scope = scope.where(inbox_id: args[:inbox_id]) if args[:inbox_id].present?
    outgoing = scope.where(message_type: :outgoing)
    bots = outgoing.where(sender_type: 'AgentBot')
    ai_bot_id = AgentBot.where(account_id: account.id, name: AiAgent::BOT_NAME).pick(:id)
    by_member = outgoing.where(sender_type: 'User').reorder(nil).group(:sender_id).count.transform_keys { |id| agent_name(id) }
    { from: time(period.first), to: time(period.last), received_from_customers: scope.where(message_type: :incoming).count,
      sent_by_team: by_member, sent_by_chatssync_ai: bots.where(sender_id: ai_bot_id).count,
      sent_by_chatbot_and_flows: bots.where.not(sender_id: ai_bot_id).count,
      sent_by_campaigns_and_system: outgoing.where(sender_type: nil).count,
      new_chats: account.conversations.where(created_at: period, inbox_id: user.assigned_inboxes.select(:id)).count }
  end

  def tool_agent_activity(args)
    period = range(args)
    sent = account.messages.where(created_at: period, private: false, message_type: :outgoing, sender_type: 'User')
                  .reorder(nil).group(:sender_id).count
    resolved = ReportingEvent.where(account_id: account.id, name: 'conversation_resolved', created_at: period).group(:user_id).count
    { from: time(period.first), to: time(period.last),
      members: account.users.map { |member| { name: member.name, messages_sent: sent[member.id] || 0, chats_resolved: resolved[member.id] || 0 } } }
  end

  def tool_list_team(_args)
    { members: account.account_users.includes(:user).map { |member| { id: member.user_id, name: member.user&.name, role: member.role } },
      teams: account.teams.map { |team| { id: team.id, name: team.name } },
      inboxes: user.assigned_inboxes.map { |inbox| { id: inbox.id, name: inbox.name, type: inbox.channel_type.demodulize } },
      labels: account.labels.pluck(:title) }
  end

  def tool_list_canned_responses(_args)
    { canned_responses: account.canned_responses.limit(50).map { |canned| { short_code: canned.short_code, content: canned.content.truncate(150) } } }
  end

  def tool_plan_usage(_args)
    { plan: account.plan&.name || 'No plan (no limits)', ends: time(account.plan_ends_at),
      usage: account.plan_usage_summary.select { |_key, value| value[:limit] } }
  end

  def tool_ai_settings(_args)
    agent = account.ai_agent
    return { enabled: false, note: 'The AI agent is not set up yet.' } if agent.nil?

    { enabled: agent.enabled, reply_scope: agent.reply_scope, business_name: agent.business_name,
      business_info: agent.business_info.to_s.truncate(1500), instructions: agent.instructions,
      faqs: account.ai_knowledge_items.faqs.count, images: account.ai_knowledge_items.images.count }
  end

  def tool_add_labels(args)
    chat = conversation(args[:conversation_id])
    chat.add_labels(Array(args[:labels]).map { |label| label.to_s.parameterize })
    { done: true, labels: chat.reload.label_list }
  end

  def tool_assign_conversation(args)
    chat = conversation(args[:conversation_id])
    attrs = {}
    attrs[:assignee_id] = account.users.find(args[:agent_id]).id if args[:agent_id].present?
    attrs[:team_id] = account.teams.find(args[:team_id]).id if args[:team_id].present?
    chat.update!(attrs)
    { done: true }
  end

  def tool_change_status(args)
    conversation(args[:conversation_id]).update!(status: args[:status])
    { done: true }
  end

  def tool_add_private_note(args)
    chat = conversation(args[:conversation_id])
    Messages::MessageBuilder.new(user, chat, { content: args[:text], private: true }.with_indifferent_access).perform
    { done: true }
  end

  def tool_send_reply(args)
    chat = conversation(args[:conversation_id])
    raise Error, I18n.t('errors.plan.conversation_locked') if chat.additional_attributes&.dig('plan_locked')

    Messages::MessageBuilder.new(user, chat, { content: args[:text], private: false }.with_indifferent_access).perform
    { done: true }
  end

  def tool_create_canned_response(args)
    account.canned_responses.create!(short_code: args[:short_code].to_s.parameterize, content: args[:content])
    { done: true }
  end

  def tool_create_label(args)
    account.labels.create!(title: args[:title].to_s.parameterize, color: args[:color].presence || '#1f93ff')
    { done: true }
  end

  def tool_add_faqs(args)
    created = Array(args[:faqs]).count do |faq|
      account.ai_knowledge_items.new(kind: 'faq', question: faq['question'], answer: faq['answer']).save
    end
    { done: true, added: created }
  end

  def tool_add_product_images(args)
    errors = []
    added = 0
    Array(args[:images]).each do |item|
      error = save_product_image(item)
      error ? errors << error : added += 1
    end
    raise Error, errors.first if added.zero? && errors.any?

    { done: true, added: added, problems: errors.presence }.compact
  end

  # Returns an error message, or nil when the picture was saved.
  def save_product_image(item)
    blob = ActiveStorage::Blob.find_signed(item['signed_id'].to_s)
    return "#{item['image']}: picture not found, please attach it again" if blob.nil?

    record = account.ai_knowledge_items.new(kind: 'image', question: item['name'].presence || blob.filename.base, answer: item['details'])
    record.image.attach(blob)
    record.save ? nil : record.errors.full_messages.to_sentence
  end

  def tool_update_ai_agent(args)
    agent = account.ai_agent || account.create_ai_agent!(business_name: account.name)
    attrs = args.slice(:enabled, :reply_scope, :instructions, :handoff_message).compact
    attrs[:business_info] = [agent.business_info, args[:business_info_to_add]].compact_blank.join("\n") if args[:business_info_to_add].present?
    agent.update!(attrs)
    { done: true }
  end
end
