# Copilot tools for Settings > Smart features, like "email me when a customer wants a bulk order",
# "turn on shipping updates" or "send new leads to my Google Sheet".
class CsCopilot::SmartFeatureTools
  READ_TOOLS = %w[smart_features].freeze
  WRITE_TOOLS = %w[update_smart_features].freeze
  ADMIN_TOOLS = %w[update_smart_features].freeze

  def self.fn(name, description, properties = {}, required = [])
    { type: 'function', function: { name: name, description: description,
                                     parameters: { type: 'object', properties: properties, required: required } } }
  end

  SWITCHES = %w[typing_indicator returning_customers payment_check photo_search follow_up review_request broadcast_tools
                whatsapp_forms repeat_reminder cod_confirm cod_reminder ship_updates cart_recovery ad_report meta_sales daily_report
                email_alerts alert_order alert_handoff google_sheet sheet_leads sheet_orders sheet_bookings sheet_ai health_guard
                stop_opt_out app_webhook].freeze
  VALUES = %w[follow_up_hours review_link cart_delay_hours cod_reminder_hours cod_confirmed_text cod_cancelled_text alert_rules
              sheet_url].freeze
  NAMES = { type: 'array', items: { type: 'string' } }.freeze

  DEFINITIONS = [
    fn('smart_features', 'Show which smart features are on (AI extras, store updates, alerts, Google Sheet, reports) and their settings.'),
    fn('update_smart_features', "Turn smart features on or off and change their settings. Features: #{SWITCHES.join(', ')}. " \
                                'cod_confirm = COD confirmation, ship_updates = tracking on WhatsApp, cart_recovery = Shopify cart reminder, ' \
                                'email_alerts with alert_rules = email when ... (owner\'s words), google_sheet with sheet_url = Apps Script link. ' \
                                'WhatsApp numbers and templates are picked on the Smart features page.',
       { turn_on: NAMES, turn_off: NAMES,
         settings: { type: 'array', description: "Other settings: #{VALUES.join(', ')}",
                     items: { type: 'object', properties: { key: { type: 'string' }, value: { type: 'string' } } } } })
  ].freeze

  pattr_initialize [:account!, :user!]

  def self.handles?(name)
    (READ_TOOLS + WRITE_TOOLS).include?(name)
  end

  def execute(name, args)
    send("tool_#{name}", args.with_indifferent_access)
  end

  def summary(_name, args)
    changes(args.with_indifferent_access).map { |key, value| "#{key.humanize} → #{value}" }.join(', ').prepend('Change smart features: ')
  end

  private

  def tool_smart_features(_args)
    account.smart_features_with_defaults.except(*AccountSmartFeatures::SMART_FEATURE_INTERNAL_KEYS)
  end

  def tool_update_smart_features(args)
    account.update_smart_features!(changes(args))
    { done: true, page: 'Settings > Smart features' }
  end

  def changes(args)
    switches = (Array(args[:turn_on]) & SWITCHES).index_with(true).merge((Array(args[:turn_off]) & SWITCHES).index_with(false))
    values = Array(args[:settings]).to_h { |item| [item['key'].to_s, item['value']] }.slice(*VALUES)
    switches.merge(values)
  end
end
