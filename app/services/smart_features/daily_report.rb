# Smart features > "Daily report": yesterday's numbers for the business owner, emailed at 9 am.
class SmartFeatures::DailyReport
  pattr_initialize [:account!]

  def stats
    day = Time.current.in_time_zone(Plan::TIMEZONE).yesterday
    range = day.beginning_of_day..day.end_of_day
    messages = account.messages.where(created_at: range, private: false)
    orders = account.orders.where(created_at: range).where.not(status: 'cancelled')
    {
      'date' => day.to_date.to_fs(:long),
      'new_chats' => account.conversations.where(created_at: range).count,
      'customer_messages' => messages.where(message_type: :incoming).count,
      'ai_replies' => messages.where(message_type: :outgoing).where("content_attributes ->> 'ai_generated' = 'true'").count,
      'team_replies' => messages.where(message_type: :outgoing, sender_type: 'User').count,
      'orders' => orders.count,
      'orders_total' => orders.sum(:total).to_f.round,
      'appointments' => account.appointments.where(created_at: range).where.not(status: 'cancelled').count,
      'waiting_now' => account.conversations.open.where.not(waiting_since: nil).count
    }
  end
end
