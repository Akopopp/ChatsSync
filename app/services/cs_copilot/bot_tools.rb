# Copilot tools for chatbot flows and the media gallery. These live in the ChatsSync bot
# service (CHATSSYNC_BOT_URL, shared key CHATSSYNC_BOT_KEY). Every flow or file is also
# matched against this account's own list before it is read or changed.
class CsCopilot::BotTools
  READ_TOOLS = %w[list_flows get_flow list_gallery].freeze
  WRITE_TOOLS = %w[create_flow edit_flow_text publish_flow unpublish_flow assign_flow_inbox delete_flow
                   add_to_gallery remove_from_gallery].freeze
  MAX_STEPS = 40
  MAX_FILE_SIZE = 16.megabytes

  def self.fn(name, description, properties = {}, required = [])
    { type: 'function', function: { name: name, description: description,
                                     parameters: { type: 'object', properties: properties, required: required } } }
  end

  FLOW = { type: 'integer', description: 'Flow id from list_flows' }.freeze

  DEFINITIONS = [
    fn('list_flows', 'List the chatbot flows with their status (published or draft) and inbox.'),
    fn('get_flow', 'Show the steps of one chatbot flow: each step id, type, text, buttons and where it goes next.',
       { flow_id: FLOW }, ['flow_id']),
    fn('list_gallery', 'List the files in the media gallery used by chatbot flows and templates.'),
    fn('create_flow', 'Create a new empty chatbot flow (steps are then built in the Chatbot Builder).',
       { name: { type: 'string' }, inbox_id: { type: 'integer' } }, ['name']),
    fn('edit_flow_text', 'Change the message text of one step in a chatbot flow (get step ids from get_flow).',
       { flow_id: FLOW, step_id: { type: 'string' }, text: { type: 'string' } }, %w[flow_id step_id text]),
    fn('publish_flow', 'Publish a chatbot flow so it starts replying in its inbox.', { flow_id: FLOW }, ['flow_id']),
    fn('unpublish_flow', 'Stop a chatbot flow (back to draft).', { flow_id: FLOW }, ['flow_id']),
    fn('assign_flow_inbox', 'Connect a chatbot flow to an inbox (get inbox ids from list_team).',
       { flow_id: FLOW, inbox_id: { type: 'integer' } }, %w[flow_id inbox_id]),
    fn('delete_flow', 'Delete a chatbot flow.', { flow_id: FLOW }, ['flow_id']),
    fn('add_to_gallery', 'Upload pictures, videos or files the user attached to the media gallery.',
       { images: { type: 'array', items: { type: 'object', properties: {
         image: { type: 'string', description: 'Attached file, like img1' }
       } } } }, ['images']),
    fn('remove_from_gallery', 'Delete files from the media gallery by id (get ids from list_gallery).',
       { ids: { type: 'array', items: { type: 'integer' } } }, ['ids'])
  ].freeze

  pattr_initialize [:account!]

  def self.handles?(name)
    (READ_TOOLS + WRITE_TOOLS).include?(name)
  end

  def execute(name, args)
    send("tool_#{name}", args.with_indifferent_access)
  end

  def summary(name, args)
    args = args.with_indifferent_access
    case name
    when 'create_flow' then "Create chatbot flow \"#{args[:name]}\""
    when 'edit_flow_text' then "Change step \"#{args[:step_id]}\" of #{flow_label(args[:flow_id])} to: \"#{args[:text].to_s.truncate(150)}\""
    when 'publish_flow' then "Publish #{flow_label(args[:flow_id])}"
    when 'unpublish_flow' then "Stop #{flow_label(args[:flow_id])}"
    when 'assign_flow_inbox' then "Connect #{flow_label(args[:flow_id])} to inbox #{inbox_name(args[:inbox_id])}"
    when 'delete_flow' then "Delete #{flow_label(args[:flow_id])}"
    when 'add_to_gallery' then "Upload #{Array(args[:images]).size} file(s) to the media gallery"
    when 'remove_from_gallery' then "Delete #{Array(args[:ids]).size} file(s) from the media gallery"
    end
  end

  private

  def tool_list_flows(_args)
    inboxes = account.inboxes.pluck(:id, :name).to_h
    { flows: flows.map { |flow| { id: flow['id'], name: flow['name'], status: flow['status'], inbox: inboxes[flow['inbox_id']] } } }
  end

  def tool_get_flow(args)
    flow = full_flow(args[:flow_id])
    nodes = flow.dig('definition', 'nodes') || {}
    { id: flow['id'], name: flow['name'], status: flow['status'], start_step: flow.dig('definition', 'start'),
      steps: nodes.first(MAX_STEPS).map { |id, node| step_summary(id, node) } }
  end

  def tool_list_gallery(_args)
    { files: gallery.first(60).map { |file| { id: file['id'], name: file['original_name'], type: file['type'] } } }
  end

  def tool_create_flow(args)
    inbox_id = args[:inbox_id].presence && account.inboxes.find(args[:inbox_id]).id
    result = request(:post, '/api/flows', json: { account_id: account.id, name: args[:name].to_s.truncate(80), inbox_id: inbox_id })
    { done: true, flow_id: result.dig('flow', 'id') }
  end

  def tool_edit_flow_text(args)
    flow = full_flow(args[:flow_id])
    definition = flow['definition']
    node = definition.dig('nodes', args[:step_id].to_s)
    raise CsCopilot::Tools::Error, "Step #{args[:step_id]} not found in this flow." if node.nil?
    raise CsCopilot::Tools::Error, 'That step has no message text to change.' unless node.key?('text')

    node['text'] = args[:text].to_s
    request(:put, "/api/flows/#{flow['id']}", json: { definition: definition })
    { done: true }
  end

  def tool_publish_flow(args)
    request(:post, "/api/flows/#{own_flow(args[:flow_id])['id']}/publish")
    { done: true }
  end

  def tool_unpublish_flow(args)
    request(:post, "/api/flows/#{own_flow(args[:flow_id])['id']}/unpublish")
    { done: true }
  end

  def tool_assign_flow_inbox(args)
    inbox = account.inboxes.find(args[:inbox_id])
    request(:post, "/api/flows/#{own_flow(args[:flow_id])['id']}/assign-inbox", json: { inbox_id: inbox.id })
    { done: true }
  end

  def tool_delete_flow(args)
    request(:delete, "/api/flows/#{own_flow(args[:flow_id])['id']}")
    { done: true }
  end

  def tool_add_to_gallery(args)
    uploaded = Array(args[:images]).count do |item|
      blob = ActiveStorage::Blob.find_signed(item['signed_id'].to_s)
      next false if blob.nil? || blob.byte_size > MAX_FILE_SIZE

      upload_blob(blob)
      true
    end
    raise CsCopilot::Tools::Error, 'The files were not found. Please attach them again.' if uploaded.zero?

    { done: true, uploaded: uploaded }
  end

  def tool_remove_from_gallery(args)
    own_ids = gallery.pluck('id')
    ids = Array(args[:ids]).map(&:to_i) & own_ids
    ids.each { |id| request(:delete, "/api/media/#{id}") }
    { done: true, removed: ids.size }
  end

  def step_summary(id, node)
    { step: id, type: node['type'], text: node['text'].to_s.truncate(200).presence,
      buttons: Array(node['buttons']).map { |button| "#{button['title']} -> #{button['next']}" }.presence,
      next: node['next'] }.compact
  end

  def flows
    @flows ||= Array(request(:get, "/api/flows?account_id=#{account.id}")['flows'])
  end

  def gallery
    @gallery ||= Array(request(:get, "/api/media?account_id=#{account.id}")['media'])
  end

  def own_flow(id)
    flows.find { |flow| flow['id'].to_i == id.to_i } || raise(CsCopilot::Tools::Error, "Flow #{id} not found.")
  end

  def full_flow(id)
    request(:get, "/api/flows/#{own_flow(id)['id']}")['flow']
  end

  def inbox_name(id)
    account.inboxes.find_by(id: id)&.name || id
  end

  def flow_label(id)
    name = own_flow(id)['name']
    "flow \"#{name}\""
  rescue CsCopilot::Tools::Error
    "flow #{id}"
  end

  # The gallery keeps the file name it receives, so the upload uses the original name.
  def upload_blob(blob)
    Dir.mktmpdir do |dir|
      path = File.join(dir, blob.filename.sanitized)
      File.binwrite(path, blob.download)
      File.open(path) { |file| request(:post, '/api/upload', multipart: { account_id: account.id, file: file }) }
    end
  end

  def request(method, path, json: nil, multipart: nil)
    base = ENV.fetch('CHATSSYNC_BOT_URL', '').chomp('/')
    raise CsCopilot::Tools::Error, 'Chatbot flows and the gallery are not connected on this server yet.' if base.blank?

    # The shared key and account tell the bot this call comes from ChatsSync for this account.
    headers = { 'X-CS-Service-Key' => ENV.fetch('CHATSSYNC_BOT_KEY', ''), 'X-CS-Account' => account.id.to_s }
    options = { timeout: 8, headers: headers }
    if multipart
      options.merge!(body: multipart, multipart: true)
    elsif json
      options.merge!(body: json.to_json, headers: headers.merge('Content-Type' => 'application/json'))
    end
    response = HTTParty.public_send(method, "#{base}#{path}", **options)
    raise CsCopilot::Tools::Error, "The chatbot service returned an error (#{response.code})." unless response.success?

    response.parsed_response.is_a?(Hash) ? response.parsed_response : {}
  end
end
