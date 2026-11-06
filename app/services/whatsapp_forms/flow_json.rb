# The WhatsApp Flow JSON of a WhatsApp form: one screen with the questions and a submit button. The answers come
# back in the customer's reply (no endpoint is needed); WhatsappForms::Response reads them.
module WhatsappForms::FlowJson
  SCREEN = 'FORM'.freeze
  INPUT_TYPES = { 'number' => 'number', 'email' => 'email', 'phone' => 'phone' }.freeze

  module_function

  def build(form)
    { version: '7.1', screens: [screen(form)] }
  end

  def screen(form)
    children = []
    children << { type: 'TextBody', text: form.intro } if form.intro.present?
    children.concat(form.fields.map { |field| component(field) })
    children << { type: 'Footer', label: form.submit_label,
                  'on-click-action': { name: 'complete', payload: form.fields.to_h { |field| [field['key'], "${form.#{field['key']}}"] } } }
    { id: SCREEN, title: form.title, terminal: true, success: true, layout: { type: 'SingleColumnLayout', children: children } }
  end

  def component(field)
    base = { name: field['key'], label: field['label'], required: field['required'] }
    case field['type']
    when 'long_text' then base.merge(type: 'TextArea')
    when 'date' then base.merge(type: 'DatePicker')
    when 'choice'
      base.merge(type: 'Dropdown', 'data-source': field['options'].each_with_index.map { |option, index| { id: "o#{index + 1}", title: option } })
    else base.merge(type: 'TextInput', 'input-type': INPUT_TYPES.fetch(field['type'], 'text'))
    end
  end
end
