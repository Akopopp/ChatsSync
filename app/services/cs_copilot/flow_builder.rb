# Turns the steps Copilot describes into a chatbot flow definition the bot service runs and the
# Chatbot Builder opens (same format the builder saves), laid out top to bottom.
class CsCopilot::FlowBuilder
  MAX_STEPS = 40
  MAX_BUTTONS = 3
  MAX_ROWS = 10

  pattr_initialize [:steps!, :keywords, :gallery]

  def definition
    raise CsCopilot::Tools::Error, 'Add at least one step.' if items.empty?

    { start: items.first[:id], trigger: { keywords: keywords.to_s.split(',').map(&:strip).compact_blank, fuzzy: false, sensitivity: 80 },
      layout: layout, nodes: items.to_h { |step| [step[:id], node(step)] } }
  end

  private

  def items
    @items ||= Array(steps).first(MAX_STEPS).map(&:with_indifferent_access).each_with_index.map do |step, index|
      step.merge(id: step[:id].to_s.parameterize(separator: '_').presence || "step_#{index + 1}")
    end.uniq { |step| step[:id] }
  end

  def ids
    @ids ||= items.pluck(:id)
  end

  # A link to a step that does not exist is dropped, so the flow never points nowhere.
  def link(value)
    value.to_s.parameterize(separator: '_').presence_in(ids)
  end

  def choices(step, max)
    Array(step[:choices]).first(max).map { |choice| choice.with_indifferent_access }
  end

  # WhatsApp cuts button titles at 20 characters and list rows at 24.
  def title(choice, max)
    choice[:title].to_s.truncate(max, omission: '').strip
  end

  def node(step)
    text = step[:text].to_s.strip
    case step[:type].to_s
    when 'buttons'
      { type: 'buttons', header: { type: 'none', value: '' }, text: text, footer: '', loop_menu: false, text_menu: false, next: nil,
        buttons: choices(step, MAX_BUTTONS).map { |choice| { title: title(choice, 20), next: link(choice[:next]) } } }
    when 'list'
      rows = choices(step, MAX_ROWS).map do |choice|
        { title: title(choice, 24), description: choice[:description].to_s.truncate(72), next: link(choice[:next]) }
      end
      { type: 'list', header: { type: 'none', value: '' }, body: text, button: 'Options', footer: '', loop_menu: false, text_menu: false,
        next: nil, sections: [{ title: '', rows: rows }] }
    when 'question'
      { type: 'question', text: text, save_as: step[:save_as].to_s.parameterize(separator: '_').presence || 'answer', response_format: 'any',
        timeout_seconds: 0, timeout_message: '', continue_on_timeout: false, next: link(step[:next]) }
    when 'media' then media(step, text)
    when 'tag' then { type: 'tag', labels: step[:labels].to_s.split(',').map(&:strip).compact_blank, next: link(step[:next]) }
    when 'appointment' then { type: 'appointment', text: text, button_text: 'Book Appointment', footer: '', next: link(step[:next]) }
    when 'handover' then { type: 'handover', text: text }
    else { type: 'text', text: text, next: link(step[:next]) }
    end
  end

  def media(step, caption)
    file = Array(gallery).find { |item| item['id'].to_i == step[:media_id].to_i }
    raise CsCopilot::Tools::Error, "Gallery file #{step[:media_id]} not found. Use list_gallery for ids." if file.nil?

    { type: 'media', url: file['url'], media_type: file['type'].to_s, name: file['original_name'].to_s, caption: caption, next: link(step[:next]) }
  end

  # Each level of the flow goes on its own row, so the builder shows it like a tree.
  def layout
    depth = { ids.first => 0 }
    queue = [ids.first]
    while (id = queue.shift)
      targets(items.find { |step| step[:id] == id }).each do |target|
        next if depth.key?(target)

        depth[target] = depth[id] + 1
        queue << target
      end
    end
    ids.each { |id| depth[id] ||= depth.values.max + 1 }
    positions = { 'start' => { x: 80, y: 0 } }
    depth.group_by { |_id, level| level }.each do |level, members|
      members.each_with_index { |(id, _), index| positions[id] = { x: 80 + (index * 300), y: 160 + (level * 240) } }
    end
    positions
  end

  def targets(step)
    ([step[:next]] + Array(step[:choices]).map { |choice| choice.with_indifferent_access[:next] }).filter_map { |value| link(value) }
  end
end
