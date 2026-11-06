# One filled-in WhatsApp form. Answers are kept by field label, as the customer saw them.
class WhatsappFormResponse < ApplicationRecord
  belongs_to :whatsapp_form
  belongs_to :conversation, optional: true
  belongs_to :contact, optional: true
end
