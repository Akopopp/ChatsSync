# Endpoint for WhatsApp Flow forms (the booking calendar). Every request and answer is encrypted.
class Webhooks::WhatsappFlowsController < ActionController::API
  def create
    request_data, aes_key, iv = WhatsappFlows::Crypto.decrypt(params)
    render plain: WhatsappFlows::Crypto.encrypt(answer(request_data), aes_key, iv)
  rescue WhatsappFlows::Crypto::DecryptError
    # 421 tells WhatsApp to fetch our public key again.
    head 421
  end

  private

  def answer(request_data)
    return { data: { status: 'active' } } if request_data['action'] == 'ping'
    return { data: { acknowledged: true } } if request_data.dig('data', 'error').present?

    Appointments::FlowBooking.new(flow_token: request_data['flow_token'].to_s).respond(request_data['action'], request_data['data'] || {})
  end
end
