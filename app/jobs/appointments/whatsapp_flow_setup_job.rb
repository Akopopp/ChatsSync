# Creates the WhatsApp booking form in every WhatsApp number of an account that takes appointments.
class Appointments::WhatsappFlowSetupJob < ApplicationJob
  queue_as :low

  def perform(account, force: false)
    return unless Appointments::AiBooking.enabled_for?(account)

    account.inboxes.includes(:channel).each do |inbox|
      next unless Appointments::WhatsappFlow.supported?(inbox)

      flow = Appointments::WhatsappFlow.new(inbox: inbox)
      flow.setup! if force || flow.retry_due?
    end
  end
end
