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

  SWITCH = { type: 'boolean' }.freeze
  CHANGES = {
    typing_indicator: SWITCH, returning_customers: SWITCH, payment_check: SWITCH, photo_search: SWITCH,
    follow_up: { type: 'boolean', description: 'AI follows up when a customer stops replying' },
    follow_up_hours: { type: 'integer', description: 'Hours before the follow-up (1-20)' },
    review_request: SWITCH, review_link: { type: 'string', description: 'Review page link (https://...)' },
    broadcast_tools: SWITCH, whatsapp_forms: SWITCH, repeat_reminder: SWITCH,
    cod_confirm: { type: 'boolean', description: 'Confirm Shopify / WooCommerce COD orders on WhatsApp' },
    ship_updates: { type: 'boolean', description: 'Send courier and tracking on WhatsApp when an order ships' },
    cart_recovery: { type: 'boolean', description: 'Remind Shopify customers who left the checkout' },
    cart_delay_hours: { type: 'integer', description: 'Hours before the cart reminder: 1, 2, 3, 6, 12 or 24' },
    ad_report: SWITCH, meta_sales: SWITCH, daily_report: SWITCH,
    email_alerts: { type: 'boolean', description: 'Email the admins when a chat needs them' },
    alert_order: { type: 'boolean', description: 'Email when the AI takes an order' },
    alert_handoff: { type: 'boolean', description: 'Email when the AI passes a chat to the team' },
    alert_rules: { type: 'string', description: 'Also email when ... (the owner\'s own words; the AI checks it)' },
    google_sheet: { type: 'boolean', description: 'Add new leads, orders and appointments to a Google Sheet' },
    sheet_url: { type: 'string', description: 'Apps Script web app link (https://script.google.com/macros/s/.../exec)' },
    sheet_leads: SWITCH, sheet_orders: SWITCH, sheet_bookings: SWITCH,
    health_guard: SWITCH, stop_opt_out: SWITCH
  }.freeze

  DEFINITIONS = [
    fn('smart_features', 'Show which smart features are on (AI extras, store updates, alerts, Google Sheet, reports) and their settings.'),
    fn('update_smart_features', 'Turn smart features on or off and change their settings. WhatsApp numbers and templates for ' \
                                'store messages are picked on the Smart features page.', CHANGES)
  ].freeze

  pattr_initialize [:account!, :user!]

  def self.handles?(name)
    (READ_TOOLS + WRITE_TOOLS).include?(name)
  end

  def execute(name, args)
    send("tool_#{name}", args.with_indifferent_access)
  end

  def summary(_name, args)
    "Change smart features: #{args.map { |key, value| "#{key.to_s.humanize} → #{value}" }.join(', ')}"
  end

  private

  def tool_smart_features(_args)
    account.smart_features_with_defaults.except(*AccountSmartFeatures::SMART_FEATURE_INTERNAL_KEYS)
  end

  def tool_update_smart_features(args)
    account.update_smart_features!(args.slice(*CHANGES.keys.map(&:to_s)))
    { done: true, page: 'Settings > Smart features' }
  end
end
