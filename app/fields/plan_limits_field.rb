require 'administrate/field/base'

class PlanLimitsField < Administrate::Field::Base
  LABELS = {
    'ai_replies_monthly' => 'AI replies / month',
    'ai_replies_daily' => 'AI replies / day',
    'copilot_tasks_monthly' => 'Copilot tasks / month',
    'contacts_monthly' => 'Active contacts / month',
    'agents' => 'Team members',
    'whatsapp_numbers' => 'WhatsApp numbers',
    'facebook_pages' => 'Facebook pages',
    'instagram_accounts' => 'Instagram accounts',
    'campaigns_monthly' => 'Campaigns / month',
    'chatbot_flows' => 'Chatbot flows',
    'kb_faqs' => 'AI knowledge FAQs',
    'kb_files' => 'AI knowledge files',
    'ai_voice_images' => 'AI understands voice notes and images',
    'ai_on_paid_chats' => 'AI can reply to non-ad (paid) chats'
  }.freeze

  def self.label(key)
    LABELS[key.to_s] || key.to_s.humanize
  end

  def values
    order = Plan::LIMIT_KEYS + Plan::FEATURE_KEYS
    (data.presence || {}).to_h.stringify_keys.sort_by { |key, _| order.index(key) || order.size }.to_h
  end

  def extra_keys
    values.keys - Plan::LIMIT_KEYS - Plan::FEATURE_KEYS
  end

  def extra_text
    extra_keys.map { |key| "#{key}=#{values[key]}" }.join("\n")
  end

  def to_s
    values.map { |key, value| "#{self.class.label(key)}: #{value}" }.join(', ')
  end
end
