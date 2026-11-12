# Copilot's "how do I ..." answers: where each ChatsSync feature is and how to set it up,
# so it can explain a feature and then offer to do it with its other tools.
class CsCopilot::GuideTools
  READ_TOOLS = %w[how_to].freeze
  WRITE_TOOLS = [].freeze
  ADMIN_TOOLS = [].freeze

  GUIDE = {
    'ai_agent' => 'Settings > AI Agent. Setup: turn on AI replies, choose Ad chats only or All WhatsApp chats, pick inboxes, ' \
                  '"Use my chatbot flows" (AI sends a flow box with its buttons; taps continue the flow) and "AI replies per chat" ' \
                  '(after that many replies the chat goes to the team). Business: name, details, tone, language. Knowledge: FAQs, ' \
                  'files, website, product pictures. Test it in the preview. Copilot can change these with update_ai_agent and add_faqs.',
    'chatbot_flows' => 'Chatbot Builder (left menu). A flow is boxes: text, buttons, list, question, media, tag, appointment, form, ' \
                       'catalog, condition, delay, hand over. Connect the boxes, set the inbox and Publish. One published flow per inbox. ' \
                       'Copilot can build a whole flow from a description with build_flow, edit texts, publish, stop and connect inboxes.',
    'gallery' => 'Media Gallery (left menu): upload pictures, videos and PDFs once and use them in flows and templates. ' \
                 'Copilot can upload attached files (add_to_gallery), list and delete them.',
    'catalog' => 'Settings > Catalog: turn on the catalog, add products with price, picture and category, set currency, delivery fee, ' \
                 'minimum order and "AI takes orders". On WhatsApp the AI shows products as cards with an Order now button. ' \
                 'Orders are listed on the same page. Copilot can add and change products and order status.',
    'appointments' => 'Settings > Appointments: working hours, services, slot length, reminders and the booking page link. ' \
                      'Appointments (left menu) shows the calendar. The AI offers free times and books. Copilot can list, book, ' \
                      'cancel and change booking settings.',
    'campaigns' => 'Campaigns > WhatsApp: pick an approved template, the inbox and the audience (labels or segments), then send now ' \
                   'or schedule. With Smart features > Broadcast tools on you see the audience size and Meta charge first. ' \
                   'Meta charges per marketing template message. Copilot can list campaigns and schedule one for labels.',
    'templates' => 'Templates (left menu): create a WhatsApp template (category, language, header, body with {{1}} variables, buttons) ' \
                   'and submit it; Meta approves in minutes to 24 hours. Needed for messages outside the 24-hour window. ' \
                   'Copilot can list templates and write and submit a new one.',
    'smart_features' => 'Settings > Smart features: switches for AI extras (typing, returning customers, payment screenshots, photo search, ' \
                        'follow-up), customers (reviews, repeat reminders, broadcast tools, WhatsApp forms), ads (ad report, Meta sales), you (daily report, email alerts, ' \
                        'Google Sheet) and safety. Each has a ? with how to use it. Copilot can switch them with update_smart_features.',
    'online_store' => 'Settings > Online store. Turn on COD confirmation, Shipping updates or Abandoned cart reminder, pick the ' \
                      'WhatsApp number and an approved template, then copy the store link. Shopify: Settings > Notifications > Webhooks > ' \
                      'Create webhook (Order creation, Order fulfillment, Checkout creation and update), format JSON, paste the link. ' \
                      'WooCommerce: Settings > Advanced > Webhooks (Order created / Order updated).',
    'google_sheet' => 'Smart features > Google Sheet: open your sheet > Extensions > Apps Script, paste our script, Deploy > New ' \
                      'deployment > Web app (Execute as Me, Anyone), copy the Web app URL and paste it. Leads, orders and bookings get ' \
                      'their own tabs; a tab named AI is read by the AI (prices, stock).',
    'email_alerts' => 'Smart features > Email alerts: emails all admins when the AI takes an order or passes a chat to the team, plus ' \
                      'your own rule in plain words, like "a customer asks for a bulk order".',
    'automation' => 'Settings > Automation: When (event) / If (conditions) / Do (actions) rules, like "when a customer writes price, add ' \
                    'the label price and email me". Actions include send message, labels, assign, email the admins, turn AI off or on, ' \
                    'add to Google Sheet and webhook. Copilot can create them with create_automation.',
    'whatsapp_forms' => 'Smart features > WhatsApp forms > Manage forms: build a form that opens inside WhatsApp and send it from a chat. ' \
                        'Answers come back as a private note and can be downloaded.',
    'inboxes' => 'Settings > Inboxes: connect WhatsApp (official API), Facebook, Instagram or a website chat. Extra WhatsApp numbers ' \
                 'depend on the plan.',
    'team' => 'Settings > Agents: invite team members (by email) as agent or administrator. Teams group agents; assign chats to a ' \
              'person or team from the chat.',
    'labels' => 'Settings > Labels: create labels like lead, vip, paid; add them in a chat; filter chats and send campaigns by label.',
    'billing' => 'Settings > Plan & Usage: your plan, days left, AI replies used today and this month, contacts, team members, ' \
                 'broadcasts and add-ons. To renew or upgrade, message ChatsSync on WhatsApp.',
    'reports' => 'Reports (left menu): chats, reply times, agents, labels, inboxes, bot and CSAT. The Dashboard shows today at a glance.'
  }.freeze

  def self.fn(name, description, properties = {}, required = [])
    { type: 'function', function: { name: name, description: description,
                                     parameters: { type: 'object', properties: properties, required: required } } }
  end

  DEFINITIONS = [
    fn('how_to', 'Where a ChatsSync feature is and how to set it up. Use it when the user asks how something works or how to do it.',
       { topic: { type: 'string', enum: GUIDE.keys } }, ['topic'])
  ].freeze

  pattr_initialize [:account!, :user!]

  def self.handles?(name)
    READ_TOOLS.include?(name)
  end

  def execute(_name, args)
    { guide: GUIDE.fetch(args.with_indifferent_access[:topic].to_s) { GUIDE.keys.join(', ') } }
  end

  def summary(*); end
end
