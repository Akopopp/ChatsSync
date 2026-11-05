# Screens of the WhatsApp booking form: choose service and day on a calendar, then a time and name,
# then a confirmation. Free days and times come live from our endpoint (Appointments::FlowBooking).
module Appointments::WhatsappFlowJson
  module_function

  def build
    {
      version: '7.1',
      data_api_version: '3.0',
      routing_model: { 'BOOK' => ['TIME'], 'TIME' => ['DONE'], 'DONE' => [] },
      screens: [book_screen, time_screen, done_screen]
    }
  end

  def string(example)
    { type: 'string', __example__: example }
  end

  def boolean(example)
    { type: 'boolean', __example__: example }
  end

  def options(example)
    { type: 'array', items: { type: 'object', properties: { id: { type: 'string' }, title: { type: 'string' },
                                                            description: { type: 'string' }, enabled: { type: 'boolean' } } },
      __example__: example }
  end

  def book_screen
    {
      id: 'BOOK', title: 'Book an appointment',
      data: {
        business: string('Lahore Shoes House'), services: options([{ id: 'Haircut', title: 'Haircut', description: '30 min', enabled: true }]),
        show_services: boolean(true), min_date: string('2026-11-02'), max_date: string('2026-11-30'),
        unavailable_dates: { type: 'array', items: { type: 'string' }, __example__: ['2026-11-08'] },
        error: string(''), has_error: boolean(false)
      },
      layout: { type: 'SingleColumnLayout', children: [
        { type: 'TextSubheading', text: '${data.business}' },
        { type: 'TextBody', text: '${data.error}', visible: '${data.has_error}' },
        { type: 'Dropdown', name: 'service', label: 'Service', required: false, visible: '${data.show_services}',
          'data-source': '${data.services}' },
        { type: 'CalendarPicker', name: 'date', label: 'Choose a day', required: true, mode: 'single',
          'min-date': '${data.min_date}', 'max-date': '${data.max_date}', 'unavailable-dates': '${data.unavailable_dates}' },
        { type: 'Footer', label: 'See free times',
          'on-click-action': { name: 'data_exchange', payload: { step: 'times', service: '${form.service}', date: '${form.date}' } } }
      ] }
    }
  end

  def time_screen
    {
      id: 'TIME', title: 'Choose a time',
      data: {
        day_label: string('Monday, 2 November'), date: string('2026-11-02'), service: string('Haircut'),
        times: options([{ id: '15:00', title: '3:00 PM', description: '', enabled: true }]),
        customer_name: string('Ali'), error: string(''), has_error: boolean(false)
      },
      layout: { type: 'SingleColumnLayout', children: [
        { type: 'TextSubheading', text: '${data.day_label}' },
        { type: 'TextBody', text: '${data.error}', visible: '${data.has_error}' },
        { type: 'Dropdown', name: 'time', label: 'Time', required: true, 'data-source': '${data.times}' },
        { type: 'TextInput', name: 'customer_name', label: 'Your name', 'input-type': 'text', required: true,
          'init-value': '${data.customer_name}' },
        { type: 'Footer', label: 'Book appointment',
          'on-click-action': { name: 'data_exchange', payload: { step: 'book', date: '${data.date}', service: '${data.service}',
                                                                 time: '${form.time}', customer_name: '${form.customer_name}' } } }
      ] }
    }
  end

  def done_screen
    {
      id: 'DONE', title: 'Booked', terminal: true, success: true,
      data: { heading: string('You are booked!'), label: string('Mon 2 Nov, 3:00 PM (Haircut)'), appointment_id: string('12') },
      layout: { type: 'SingleColumnLayout', children: [
        { type: 'TextHeading', text: '${data.heading}' },
        { type: 'TextBody', text: '${data.label}' },
        { type: 'Footer', label: 'Done', 'on-click-action': { name: 'complete', payload: { appointment_id: '${data.appointment_id}' } } }
      ] }
    }
  end
end
