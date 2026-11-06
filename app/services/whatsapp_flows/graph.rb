# Meta Graph API calls for WhatsApp Flows (the booking calendar and WhatsApp forms): create a flow,
# upload its JSON, publish it. Uses the access token of the WhatsApp number the flow is for.
module WhatsappFlows::Graph
  URL = 'https://graph.facebook.com/v21.0'.freeze

  module_function

  # Creates a flow in the number's WhatsApp Business Account, uploads the JSON and publishes it. Returns the flow id.
  def publish(channel, name:, categories:, json:, endpoint_uri: nil)
    token = channel.provider_config['api_key']
    body = { name: name, categories: categories, endpoint_uri: endpoint_uri }.compact
    id = request(token, :post, "#{URL}/#{channel.provider_config['business_account_id']}/flows", body: body)['id']
    raise 'WhatsApp did not return a form id' if id.blank?

    upload_json(token, id, json)
    request(token, :post, "#{URL}/#{id}/publish")
    id
  end

  def upload_json(token, id, json)
    Tempfile.create(['flow', '.json']) do |file|
      file.write(json.to_json)
      file.rewind
      result = request(token, :post, "#{URL}/#{id}/assets", body: { name: 'flow.json', asset_type: 'FLOW_JSON', file: file }, multipart: true)
      errors = Array(result['validation_errors'])
      raise "Form check failed: #{errors.map { |error| error['message'] }.join('; ')}" if errors.any?
    end
  end

  # Sends JSON, or a multipart form when a file is attached. Raises Meta's error message on failure.
  def request(token, method, url, body: {}, multipart: false)
    headers = { 'Authorization' => "Bearer #{token}" }
    headers['Content-Type'] = 'application/json' unless multipart
    response = HTTParty.public_send(method, url, headers: headers, body: multipart ? body : body.to_json, multipart: multipart, timeout: 20)
    parsed = response.parsed_response.is_a?(Hash) ? response.parsed_response : {}
    return parsed if response.success?

    raise(parsed.dig('error', 'error_user_msg').presence || parsed.dig('error', 'message').presence || response.body.to_s.truncate(200))
  end
end
