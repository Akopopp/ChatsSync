# Publishes a WhatsApp form as a WhatsApp Flow in the WhatsApp Business Account of one number, once per version.
# Published flows cannot be changed, so an edited form gets a new flow the next time it is sent.
class WhatsappForms::Publisher
  pattr_initialize [:form!, :inbox!]

  def flow_id
    state = form.flows[inbox.id.to_s] || {}
    return state['flow_id'] if state['version'] == form.version && state['flow_id'].present?

    publish!
  end

  private

  def publish!
    raise I18n.t('whatsapp_forms.errors.whatsapp_only') unless Appointments::WhatsappFlow.supported?(inbox)

    id = WhatsappFlows::Graph.publish(inbox.channel, name: "ChatsSync form #{form.id} #{Time.current.strftime('%Y%m%d%H%M%S')}",
                                                     categories: ['LEAD_GENERATION'], json: WhatsappForms::FlowJson.build(form))
    form.with_lock do
      flows = form.flows.merge(inbox.id.to_s => { 'flow_id' => id, 'version' => form.version })
      form.update_columns(flows: flows) # rubocop:disable Rails/SkipsModelValidations
    end
    id
  end
end
