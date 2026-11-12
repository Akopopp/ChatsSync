# ChatsSync extras an account can switch on from Settings > Smart features.
# Everything is off until an admin turns it on, so existing accounts are not affected.
# The one exception is the AI's "typing..." on WhatsApp, which only runs when the AI itself is on.
module AccountSmartFeatures
  SMART_FEATURE_DEFAULTS = {
    'typing_indicator' => true,
    'returning_customers' => false,
    'payment_check' => false,
    'photo_search' => false,
    'follow_up' => false,
    'follow_up_hours' => 3,
    'review_request' => false,
    'review_link' => '',
    'broadcast_tools' => false,
    'whatsapp_forms' => false,
    'repeat_reminder' => false,
    'repeat_reminder_days' => 30,
    'repeat_reminder_inbox_id' => 0,
    'repeat_reminder_template' => '',
    'repeat_reminder_template_language' => '',
    'cod_confirm' => false,
    'cod_only' => true,
    'cod_inbox_id' => 0,
    'cod_template' => '',
    'cod_template_language' => '',
    'cod_token' => '',
    'ship_updates' => false,
    'ship_inbox_id' => 0,
    'ship_template' => '',
    'ship_template_language' => '',
    'cart_recovery' => false,
    'cart_delay_hours' => 1,
    'cart_inbox_id' => 0,
    'cart_template' => '',
    'cart_template_language' => '',
    'ad_report' => false,
    'meta_sales' => false,
    'meta_sales_when' => 'confirmed',
    'daily_report' => false,
    'email_alerts' => false,
    'alert_order' => true,
    'alert_handoff' => true,
    'alert_rules' => '',
    'google_sheet' => false,
    'sheet_url' => '',
    'sheet_leads' => true,
    'sheet_orders' => true,
    'sheet_bookings' => true,
    'health_guard' => false,
    'stop_opt_out' => false
  }.freeze
  # Set by ChatsSync, never by the settings page.
  SMART_FEATURE_INTERNAL_KEYS = %w[cod_token].freeze
  SMART_FEATURE_TEXT_KEYS = %w[cod_template cod_template_language cod_token repeat_reminder_template repeat_reminder_template_language
                               ship_template ship_template_language cart_template cart_template_language].freeze
  SMART_FEATURE_CHOICES = { 'meta_sales_when' => %w[confirmed new delivered], 'repeat_reminder_days' => %w[30 7 14 21 45 60 90 180],
                            'cart_delay_hours' => %w[1 2 3 6 12 24] }.freeze
  STORE_FEATURES = %w[cod_confirm ship_updates cart_recovery].freeze
  FOLLOW_UP_HOURS = (1..20)

  def self.editable_keys
    SMART_FEATURE_DEFAULTS.keys - SMART_FEATURE_INTERNAL_KEYS
  end

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
    merged = smart_features_with_defaults.merge(clean)
    # The secret part of the store webhook link, made once when a store feature is first switched on.
    merged['cod_token'] = SecureRandom.alphanumeric(32) if merged.values_at(*STORE_FEATURES).any?(true) && merged['cod_token'].blank?
    update!(smart_features: merged)
  end

  private

  def cast_smart_feature(key, value)
    return value.to_s.strip.first(500) if key == 'alert_rules'
    return value.to_s.strip.first(200) if SMART_FEATURE_TEXT_KEYS.include?(key)
    return smart_feature_choice(key, value) if SMART_FEATURE_CHOICES.key?(key)

    case key
    when 'follow_up_hours' then value.to_i.clamp(FOLLOW_UP_HOURS.min, FOLLOW_UP_HOURS.max)
    when 'cod_inbox_id', 'repeat_reminder_inbox_id', 'ship_inbox_id', 'cart_inbox_id' then value.to_i
    when 'review_link' then value.to_s.strip.match?(%r{\Ahttps?://\S+\z}) ? value.to_s.strip.truncate(500) : ''
    when 'sheet_url' then value.to_s.strip.match?(SmartFeatures::GoogleSheet::URL) ? value.to_s.strip : ''
    else ActiveModel::Type::Boolean.new.cast(value) == true
    end
  end

  # One of the allowed values (numbers stay numbers), or the first one.
  def smart_feature_choice(key, value)
    choice = SMART_FEATURE_CHOICES[key].include?(value.to_s) ? value.to_s : SMART_FEATURE_CHOICES[key].first
    SMART_FEATURE_DEFAULTS[key].is_a?(Integer) ? choice.to_i : choice
  end
end
