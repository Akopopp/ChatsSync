# The WhatsApp calendar form for booking. It opens inside WhatsApp: the customer picks a service,
# a day on a calendar, a free time and their name. It is created and published automatically in
# each client's own WhatsApp account, and talks to our endpoint for the live free times.
class Appointments::WhatsappFlow
  VERSION = 1 # raise to publish an updated form everywhere
  GRAPH = 'https://graph.facebook.com/v21.0'.freeze
  CTA = 'Choose date & time'.freeze

  pattr_initialize [:inbox!]

  def self.endpoint_url
    "#{ENV.fetch('FRONTEND_URL', '').chomp('/')}/webhooks/whatsapp_flows"
  end

  # Whatsapp Cloud numbers can show the form; other channels get the times as text.
  def self.supported?(inbox)
    inbox&.channel.is_a?(Channel::Whatsapp) && inbox.channel.provider == 'whatsapp_cloud'
  end

  def setting
    @setting ||= inbox.account.appointment_setting
  end

  def state
    (setting&.whatsapp_flows || {})[inbox.id.to_s] || {}
  end

  def ready?
    state['status'] == 'PUBLISHED' && state['version'] == VERSION && state['flow_id'].present?
  end

  def flow_id
    state['flow_id']
  end

  def setup!
    return if ready?

    save('status' => 'SETTING_UP', 'error' => nil, 'started_at' => Time.current.to_i)
    upload_public_key
    id = create_flow
    upload_json(id)
    request(:post, "#{GRAPH}/#{id}/publish")
    save('status' => 'PUBLISHED', 'flow_id' => id, 'version' => VERSION, 'error' => nil)
  rescue StandardError => e
    Rails.logger.warn("[ChatsSync] WhatsApp booking form setup failed for inbox #{inbox.id}: #{e.message}")
    save('status' => 'FAILED', 'error' => e.message.truncate(300), 'failed_at' => Time.current.to_i)
  end

  # A setup that failed is tried again after an hour, when the AI next needs the form.
  def retry_due?
    case state['status']
    when 'SETTING_UP' then state['started_at'].to_i < 10.minutes.ago.to_i
    when 'FAILED' then state['failed_at'].to_i < 1.hour.ago.to_i
    else true
    end
  end

  private

  def channel
    inbox.channel
  end

  def token
    channel.provider_config['api_key']
  end

  def upload_public_key
    request(:post, "#{GRAPH}/#{channel.provider_config['phone_number_id']}/whatsapp_business_encryption",
            body: { business_public_key: WhatsappFlows::Crypto.public_pem })
  end

  def create_flow
    result = request(:post, "#{GRAPH}/#{channel.provider_config['business_account_id']}/flows",
                     body: { name: "ChatsSync booking #{Time.current.strftime('%Y%m%d%H%M%S')}", categories: ['APPOINTMENT_BOOKING'],
                             endpoint_uri: self.class.endpoint_url })
    result['id'] || raise('WhatsApp did not return a form id')
  end

  def upload_json(id)
    Tempfile.create(['flow', '.json']) do |file|
      file.write(Appointments::WhatsappFlowJson.build.to_json)
      file.rewind
      result = request(:post, "#{GRAPH}/#{id}/assets", body: { name: 'flow.json', asset_type: 'FLOW_JSON', file: file }, multipart: true)
      errors = Array(result['validation_errors'])
      raise "Form check failed: #{errors.map { |error| error['message'] }.join('; ')}" if errors.any?
    end
  end

  # Sends JSON, or a multipart form when a file is attached.
  def request(method, url, body: {}, multipart: false)
    headers = { 'Authorization' => "Bearer #{token}" }
    headers['Content-Type'] = 'application/json' unless multipart
    response = HTTParty.public_send(method, url, headers: headers, body: multipart ? body : body.to_json, multipart: multipart, timeout: 20)
    parsed = response.parsed_response.is_a?(Hash) ? response.parsed_response : {}
    return parsed if response.success?

    raise(parsed.dig('error', 'error_user_msg').presence || parsed.dig('error', 'message').presence || response.body.to_s.truncate(200))
  end

  def save(changes)
    return if setting.nil?

    setting.with_lock do
      flows = (setting.whatsapp_flows || {}).dup
      flows[inbox.id.to_s] = (flows[inbox.id.to_s] || {}).merge(changes)
      setting.update_columns(whatsapp_flows: flows) # rubocop:disable Rails/SkipsModelValidations
    end
  end
end
