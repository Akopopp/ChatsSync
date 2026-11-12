# Emails from Settings > Smart features: the daily report, WhatsApp number health alerts and chat alerts.
class AdministratorNotifications::SmartFeaturesMailer < AdministratorNotifications::BaseMailer
  def daily_report(stats)
    send_notification("Your ChatsSync report for #{stats['date']}", action_url: dashboard_url, meta: stats)
  end

  def number_health_alert(number)
    subject = "WhatsApp number #{number['phone']}: quality is now #{number['quality_rating']}"
    send_notification(subject, action_url: settings_url('smart-features'), meta: number)
  end

  def chat_alert(meta)
    send_notification("#{meta['reason']} – #{meta['name'].presence || meta['phone']}", action_url: meta['url'], meta: meta)
  end

  private

  def dashboard_url
    "#{ENV.fetch('FRONTEND_URL', nil)}/app/accounts/#{Current.account.id}/dashboard"
  end
end
