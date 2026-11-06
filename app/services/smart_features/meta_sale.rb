# Smart features > "Send sales to Meta": when an order from a Click-to-WhatsApp ad chat reaches the chosen status,
# a Purchase event goes to Meta's Conversions API for business messaging, so the ad finds more buyers like this one.
# Only WhatsApp Cloud chats that came from an ad (they carry a ctwa_clid) are sent, each order once.
class SmartFeatures::MetaSale
  API = 'https://graph.facebook.com/v22.0'.freeze
  SENT_KEY = 'chatssync:meta_sale:%<order_id>s'.freeze
  DATASET_KEY = 'chatssync:meta_dataset:%<waba_id>s'.freeze

  def self.send_if_due(order)
    account = order.account
    return unless account.smart_feature_on?(:meta_sales) && order.status == account.smart_feature(:meta_sales_when)
    return if order.conversation&.additional_attributes&.dig('cs_ctwa_clid').blank?

    SmartFeatures::MetaSaleJob.perform_later(order.id)
  end

  pattr_initialize [:order!]

  def perform
    return if channel.blank? || clid.blank? || Rails.cache.exist?(sent_key)

    dataset = dataset_id
    return if dataset.blank?

    response = HTTParty.post("#{API}/#{dataset}/events", body: { data: [event] }.to_json, headers: headers, timeout: 20)
    return Rails.cache.write(sent_key, true, expires_in: 90.days) if response.success?

    Rails.logger.warn("[ChatsSync] Meta sale for order #{order.id} failed: #{response.body.to_s.first(300)}")
  end

  private

  def event
    {
      event_name: 'Purchase', event_time: Time.current.to_i, action_source: 'business_messaging', messaging_channel: 'whatsapp',
      user_data: { whatsapp_business_account_id: waba_id, ctwa_clid: clid },
      custom_data: { currency: currency, value: order.total.to_f }
    }
  end

  # Meta makes one dataset per WhatsApp Business Account; it is read (or made) once and remembered.
  def dataset_id
    Rails.cache.fetch(format(DATASET_KEY, waba_id: waba_id), expires_in: 30.days, skip_nil: true) do
      found = HTTParty.get("#{API}/#{waba_id}/dataset", headers: headers, timeout: 20).parsed_response
      id = dataset_from(found) || dataset_from(HTTParty.post("#{API}/#{waba_id}/dataset", headers: headers, timeout: 20).parsed_response)
      Rails.logger.warn("[ChatsSync] no Meta dataset for WABA #{waba_id}: #{found.to_s.first(300)}") if id.blank?
      id
    end
  end

  def dataset_from(response)
    return unless response.is_a?(Hash)

    response['id'] || response.dig('data', 0, 'dataset_id') || response.dig('data', 0, 'id')
  end

  def channel
    @channel ||= order.conversation&.inbox&.channel.then { |item| item if item.is_a?(Channel::Whatsapp) && item.provider == 'whatsapp_cloud' }
  end

  def clid
    order.conversation.additional_attributes&.dig('cs_ctwa_clid')
  end

  def waba_id
    channel.provider_config['business_account_id']
  end

  def headers
    { 'Authorization' => "Bearer #{channel.provider_config['api_key']}", 'Content-Type' => 'application/json' }
  end

  def currency
    code = order.account.catalog_setting&.currency.to_s.upcase.delete('.')
    code.match?(/\A[A-Z]{3}\z/) ? code : 'PKR'
  end

  def sent_key
    format(SENT_KEY, order_id: order.id)
  end
end
