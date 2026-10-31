// Limit keys sent by /plan_usage, in display order.
export const LIMIT_KEYS = [
  'ai_replies_monthly',
  'ai_replies_daily',
  'copilot_tasks_monthly',
  'contacts_monthly',
  'agents',
  'whatsapp_numbers',
  'facebook_pages',
  'instagram_accounts',
  'campaigns_monthly',
  'chatbot_flows',
  'kb_faqs',
  'kb_files',
];

// Limits that can be topped up with a pack for the current month.
export const PACK_KEYS = ['ai_replies_monthly', 'contacts_monthly'];

export const usagePercent = ({ used, limit }) => {
  if (!limit) return 0;
  return Math.min(100, Math.round(((used || 0) / limit) * 100));
};

export const whatsappLink = (number, text) =>
  `https://wa.me/${number}?text=${encodeURIComponent(text)}`;
