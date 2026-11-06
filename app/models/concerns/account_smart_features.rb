# ChatsSync extras an account can switch on from Settings > Smart features.
# Everything is off until an admin turns it on, so existing accounts are not affected.
# The one exception is the AI's "typing..." on WhatsApp, which only runs when the AI itself is on.
module AccountSmartFeatures
  SMART_FEATURE_DEFAULTS = {
    'typing_indicator' => true,
    'returning_customers' => false,
    'payment_check' => false,
    'follow_up' => false,
    'follow_up_hours' => 3,
    'review_request' => false,
    'review_link' => '',
    'daily_report' => false,
    'health_guard' => false,
    'stop_opt_out' => false
  }.freeze
  FOLLOW_UP_HOURS = (1..20)

  def smart_feature(key)
    smart_features_with_defaults[key.to_s]
  end

  def smart_feature_on?(key)
    smart_feature(key) == true
  end

  def smart_features_with_defaults
    SMART_FEATURE_DEFAULTS.merge((smart_features || {}).slice(*SMART_FEATURE_DEFAULTS.keys))
  end

  def update_smart_features!(changes)
    clean = changes.to_h.stringify_keys.slice(*SMART_FEATURE_DEFAULTS.keys).to_h { |key, value| [key, cast_smart_feature(key, value)] }
    update!(smart_features: smart_features_with_defaults.merge(clean))
  end

  private

  def cast_smart_feature(key, value)
    case key
    when 'follow_up_hours' then value.to_i.clamp(FOLLOW_UP_HOURS.min, FOLLOW_UP_HOURS.max)
    when 'review_link' then value.to_s.strip.match?(%r{\Ahttps?://\S+\z}) ? value.to_s.strip.truncate(500) : ''
    else ActiveModel::Type::Boolean.new.cast(value) == true
    end
  end
end
