# Smart features > "Bring customers back": some days after an appointment is done or an order is delivered, the customer
# gets the chosen WhatsApp template (the next visit at a salon, a clinic follow-up, a pharmacy refill).
# Each visit or order gets one reminder. Customers who sent STOP, or who already have a booking coming up, are skipped.
# Template variables are filled in this order: customer name, the service or items, the business name.
class SmartFeatures::RepeatReminder
  SENT_KEY = 'chatssync:repeat_reminder:%<kind>s:%<id>s'.freeze
  DAYS = [7, 14, 21, 30, 45, 60, 90, 180].freeze
  BATCH = 200

  pattr_initialize [:account!]

  def self.settings_for(account)
    inboxes = Whatsapp::NumberHealth.cloud_inboxes(account)
    inbox = inboxes.find { |item| item.id == account.smart_feature(:repeat_reminder_inbox_id) }
    { inboxes: inboxes.map { |item| { id: item.id, name: item.name } },
      templates: inbox ? SmartFeatures::TemplateMessage.choices(inbox.channel) : [] }
  end

  def perform
    return unless account.smart_feature_on?(:repeat_reminder) && inbox && template

    due_records.each { |record| remind(record) }
  end

  private

  def inbox
    @inbox ||= Whatsapp::NumberHealth.cloud_inboxes(account).find { |item| item.id == account.smart_feature(:repeat_reminder_inbox_id) }
  end

  def template
    @template ||= SmartFeatures::TemplateMessage.find(inbox.channel, account.smart_feature(:repeat_reminder_template),
                                                     account.smart_feature(:repeat_reminder_template_language))
  end

  def sender
    @sender ||= SmartFeatures::TemplateMessage.new(inbox: inbox, template: template)
  end

  # Visits and orders that finished between N+1 and N days ago (the job runs once a day).
  def due_records
    days = account.smart_feature(:repeat_reminder_days)
    window = (days + 1).days.ago..days.days.ago
    account.appointments.where(status: 'done', starts_at: window).includes(:contact).limit(BATCH).to_a +
      account.orders.where(status: 'delivered', updated_at: window).includes(:contact).limit(BATCH).to_a
  end

  def remind(record)
    phone = SmartFeatures::StoreOrder.phone(record.contact&.phone_number.presence || record.customer_phone)
    return if phone.blank? || skip?(record)
    return unless Redis::Alfred.set(format(SENT_KEY, kind: record.class.name.underscore, id: record.id), 1, nx: true, ex: 400.days.to_i)

    sender.deliver(sender.conversation_for(phone, record.customer_name), [record.customer_name || 'Customer', about(record), business_name])
  rescue StandardError => e
    Rails.logger.warn("[ChatsSync] repeat reminder for #{record.class.name} #{record.id} failed: #{e.message}")
  end

  def skip?(record)
    contact = record.contact
    return false if contact.nil?

    contact.label_list.include?(Whatsapp::StopOptOut::LABEL) || account.appointments.upcoming.exists?(contact_id: contact.id)
  end

  def about(record)
    return record.service.presence || 'your appointment' if record.is_a?(Appointment)

    record.items.map { |item| item['name'] }.join(', ').truncate(120)
  end

  def business_name
    @business_name ||= account.ai_agent&.business_name.presence || account.name
  end
end
