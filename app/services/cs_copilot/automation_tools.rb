# Copilot tools for Settings > Automation (When / If / Do rules), like
# "when a customer writes 'price', add the label price and email me".
class CsCopilot::AutomationTools
  READ_TOOLS = %w[list_automations].freeze
  WRITE_TOOLS = %w[create_automation set_automation_active].freeze
  ADMIN_TOOLS = WRITE_TOOLS

  EVENTS = %w[message_created conversation_created conversation_opened conversation_resolved conversation_updated].freeze
  ACTION_HELP = 'send_message [text], add_label [names], remove_label [names], add_private_note [text], email_admins [reason], ' \
                'turn_off_ai, turn_on_ai, add_to_google_sheet, assign_agent [ids], assign_team [ids], change_priority [high|low], ' \
                'resolve_conversation, open_conversation, send_webhook_event [url]'.freeze

  def self.fn(name, description, properties = {}, required = [])
    { type: 'function', function: { name: name, description: description,
                                     parameters: { type: 'object', properties: properties, required: required } } }
  end

  CONDITION = { type: 'object', properties: {
    attribute_key: { type: 'string', description: 'content, message_type, status, inbox_id, labels, phone_number or priority' },
    filter_operator: { type: 'string', description: 'equal_to, not_equal_to, contains or does_not_contain' },
    values: { type: 'array', items: { type: 'string' } }
  } }.freeze
  ACTION = { type: 'object', properties: {
    action_name: { type: 'string', description: "One of: #{ACTION_HELP}" },
    action_params: { type: 'array', items: { type: 'string' } }
  } }.freeze

  DEFINITIONS = [
    fn('list_automations', 'List the When / If / Do automation rules with their event, conditions, actions and whether they are on.'),
    fn('create_automation', 'Create a When / If / Do automation rule with at least one condition. All conditions must match (AND). ' \
                            'For "when a customer writes X" use event message_created with conditions content contains X and ' \
                            'message_type equal_to incoming.',
       { name: { type: 'string' }, event: { type: 'string', description: EVENTS.join(', ') },
         conditions: { type: 'array', items: CONDITION }, actions: { type: 'array', items: ACTION } },
       %w[name event conditions actions]),
    fn('set_automation_active', 'Turn an automation rule on or off.', { id: { type: 'integer' }, active: { type: 'boolean' } }, %w[id active])
  ].freeze

  pattr_initialize [:account!, :user!]

  def self.handles?(name)
    (READ_TOOLS + WRITE_TOOLS).include?(name)
  end

  def execute(name, args)
    send("tool_#{name}", args.with_indifferent_access)
  end

  def summary(name, args)
    args = args.with_indifferent_access
    case name
    when 'create_automation'
      "Create automation \"#{args[:name]}\": when #{args[:event]}, #{Array(args[:conditions]).size} condition(s), " \
        "do #{Array(args[:actions]).pluck('action_name').join(', ')}"
    when 'set_automation_active' then "Turn automation ##{args[:id]} #{args[:active] ? 'on' : 'off'}"
    end
  end

  private

  def tool_list_automations(_args)
    account.automation_rules.order(:id).map { |rule| rule.slice(:id, :name, :event_name, :conditions, :actions, :active) }
  end

  def tool_create_automation(args)
    raise CsCopilot::Tools::Error, "Event must be one of: #{EVENTS.join(', ')}" unless EVENTS.include?(args[:event])
    raise CsCopilot::Tools::Error, 'Add at least one condition' if Array(args[:conditions]).empty?

    conditions = Array(args[:conditions]).map do |condition|
      { 'attribute_key' => condition['attribute_key'], 'filter_operator' => condition['filter_operator'],
        'values' => Array(condition['values']), 'query_operator' => 'and' }
    end
    conditions.last['query_operator'] = nil if conditions.any?
    actions = Array(args[:actions]).map { |action| { 'action_name' => action['action_name'], 'action_params' => Array(action['action_params']) } }
    rule = account.automation_rules.create!(name: args[:name].to_s.truncate(120), event_name: args[:event], conditions: conditions,
                                            actions: actions, active: true)
    { done: true, id: rule.id, page: 'Settings > Automation' }
  rescue ActiveRecord::RecordInvalid => e
    raise CsCopilot::Tools::Error, e.record.errors.full_messages.to_sentence
  end

  def tool_set_automation_active(args)
    account.automation_rules.find(args[:id]).update!(active: args[:active])
    { done: true }
  end
end
