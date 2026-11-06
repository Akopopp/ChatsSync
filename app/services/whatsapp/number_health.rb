# Smart features > "WhatsApp number health": the quality rating and daily message limit of each WhatsApp
# number, read from Meta every few hours (Whatsapp::NumberHealthJob). Admins get an email when quality drops.
class Whatsapp::NumberHealth
  pattr_initialize [:inbox!]

  FIELDS = 'verified_name,quality_rating,messaging_limit_tier,status,name_status'.freeze
  CACHE_KEY = 'chatssync:number_health:%<inbox_id>s'.freeze
  QUALITY_RANK = { 'GREEN' => 3, 'YELLOW' => 2, 'RED' => 1 }.freeze
  LIMITS = { 'TIER_50' => '50', 'TIER_250' => '250', 'TIER_1K' => '1,000', 'TIER_2K' => '2,000', 'TIER_10K' => '10,000',
             'TIER_100K' => '100,000', 'TIER_UNLIMITED' => 'Unlimited' }.freeze

  def self.for_account(account)
    return [] unless account.smart_feature_on?(:health_guard)

    # A number not read yet (feature just switched on) is read now, so the page is not empty for 6 hours.
    cloud_inboxes(account).map do |inbox|
      health = new(inbox: inbox)
      health.refresh! if health.summary['checked_at'].blank?
      health.summary
    end
  end

  def self.cloud_inboxes(account)
    account.inboxes.where(channel_type: 'Channel::Whatsapp').includes(:channel).select { |inbox| inbox.channel.provider == 'whatsapp_cloud' }
  end

  def summary
    data = read || {}
    data.merge('inbox_id' => inbox.id, 'inbox_name' => inbox.name, 'phone' => inbox.channel.phone_number,
               'daily_limit' => LIMITS[data['messaging_limit_tier']])
  end

  # Reads the latest numbers from Meta and returns [before, after].
  def refresh!
    before = read
    response = HTTParty.get(url, headers: { 'Authorization' => "Bearer #{config['api_key']}" }, timeout: 20)
    return [before, before] unless response.success?

    after = response.parsed_response.slice(*FIELDS.split(',')).merge('checked_at' => Time.current.iso8601)
    Rails.cache.write(cache_key, after, expires_in: 3.days)
    [before, after]
  rescue StandardError => e
    Rails.logger.warn("[ChatsSync] number health check failed for inbox #{inbox.id}: #{e.message}")
    [before, before]
  end

  def self.dropped?(before, after)
    return false if before.blank? || after.blank?

    QUALITY_RANK.fetch(after['quality_rating'], 3) < QUALITY_RANK.fetch(before['quality_rating'], 3)
  end

  private

  def read
    Rails.cache.read(cache_key)
  end

  def cache_key
    format(CACHE_KEY, inbox_id: inbox.id)
  end

  def config
    inbox.channel.provider_config || {}
  end

  def url
    "#{ENV.fetch('WHATSAPP_CLOUD_BASE_URL', 'https://graph.facebook.com')}/v22.0/#{config['phone_number_id']}?fields=#{FIELDS}"
  end
end
