# Meta Graph API calls for WhatsApp Flows (the booking calendar and WhatsApp forms): create a flow,
# upload its JSON, publish it. Uses the access token of the WhatsApp number the flow is for.
module WhatsappFlows::Graph
  URL = 'https://graph.facebook.com/v21.0'.freeze

  module_function

  # Creates and publishes a flow in the number's WhatsApp Business Account in one call (the JSON goes in as
  # `flow_json`, so no file upload is needed). Returns the flow id.
  def publish(channel, name:, categories:, json:, endpoint_uri: nil)
    body = { name: name, categories: categories, endpoint_uri: endpoint_uri, flow_json: json.to_json, publish: true }.compact
    result = request(channel.provider_config['api_key'], :post, "#{URL}/#{channel.provider_config['business_account_id']}/flows", body: body)
    errors = Array(result['validation_errors'])
    raise "Form check failed: #{errors.map { |error| error['message'] }.join('; ')}" if errors.any?
    raise 'WhatsApp did not return a form id' if result['id'].blank?

    result['id']
  end

  # Sends JSON. Raises Meta's error message on failure.
  def request(token, method, url, body: {})
    headers = { 'Authorization' => "Bearer #{token}", 'Content-Type' => 'application/json' }
    response = HTTParty.public_send(method, url, headers: headers, body: body.to_json, timeout: 20)
    parsed = response.parsed_response.is_a?(Hash) ? response.parsed_response : {}
    return parsed if response.success?

    raise(parsed.dig('error', 'error_user_msg').presence || parsed.dig('error', 'message').presence || response.body.to_s.truncate(200))
  end
end
