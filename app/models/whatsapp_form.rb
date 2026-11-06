# A form that opens inside WhatsApp (a WhatsApp Flow), made in Settings > WhatsApp forms: lead details, admissions,
# clinic intake, quote requests. The team sends it from a WhatsApp chat; the answers come back to the chat as a
# private note and can be downloaded as CSV. WhatsApp's limits: 10 fields, labels up to 20 characters.
class WhatsappForm < ApplicationRecord
  TYPES = %w[text long_text number email phone choice date].freeze
  MAX_FIELDS = 10
  MAX_OPTIONS = 30
  LABEL_LENGTH = 20
  OPTION_LENGTH = 30

  belongs_to :account
  has_many :responses, class_name: 'WhatsappFormResponse', dependent: :delete_all

  validates :name, presence: true, length: { maximum: 60 }
  validates :title, presence: true, length: { maximum: 30 }
  validates :intro, length: { maximum: 1000 }
  validates :button_label, presence: true, length: { maximum: 20 }
  validates :submit_label, presence: true, length: { maximum: 30 }
  validate :validate_fields

  before_validation :normalize_fields

  # Changes whenever what WhatsApp shows changes, so a new flow is published for it.
  def version
    Digest::MD5.hexdigest([title, intro, submit_label, fields].to_json).first(12)
  end

  # Sends the form in a WhatsApp chat. The 24-hour reply window must be open.
  def deliver(conversation, sender)
    flow_id = WhatsappForms::Publisher.new(form: self, inbox: conversation.inbox).flow_id
    conversation.messages.create!(
      account_id: account_id, inbox_id: conversation.inbox_id, message_type: :outgoing, sender: sender, content: intro.presence || title,
      content_attributes: { 'whatsapp_flow' => { 'flow_id' => flow_id, 'token' => "csform:#{id}", 'cta' => button_label,
                                                 'action' => 'navigate', 'screen' => WhatsappForms::FlowJson::SCREEN } }
    )
  end

  private

  # Fields come from the settings page as [{label, type, required, options}]; each gets a fixed key (q1, q2, ...).
  def normalize_fields
    self.fields = Array(fields).first(MAX_FIELDS).each_with_index.map do |field, index|
      field = field.to_h.stringify_keys
      options = field['options'].is_a?(Array) ? field['options'] : field['options'].to_s.split("\n")
      { 'key' => "q#{index + 1}", 'label' => field['label'].to_s.squish, 'type' => TYPES.include?(field['type']) ? field['type'] : 'text',
        'required' => ActiveModel::Type::Boolean.new.cast(field['required']) == true,
        'options' => field['type'] == 'choice' ? options.map { |option| option.to_s.squish }.compact_blank.uniq.first(MAX_OPTIONS) : [] }
    end
  end

  def validate_fields
    errors.add(:fields, 'need at least one question') if fields.empty?
    fields.each do |field|
      unless field['label'].length.between?(1, LABEL_LENGTH)
        errors.add(:fields, "label \"#{field['label']}\" must be 1 to #{LABEL_LENGTH} characters")
      end
      next unless field['type'] == 'choice'

      errors.add(:fields, "\"#{field['label']}\" needs at least one choice") if field['options'].empty?
      errors.add(:fields, "choices must be up to #{OPTION_LENGTH} characters") if field['options'].any? { |option| option.length > OPTION_LENGTH }
    end
    errors.add(:fields, 'labels must be different') if fields.map { |field| field['label'].downcase }.uniq.size < fields.size
  end
end
