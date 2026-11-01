# Link to the account's public booking calendar page.
module Appointments::PublicLink
  def self.url(setting)
    return if setting&.public_token.blank?

    "#{ENV.fetch('FRONTEND_URL', '').chomp('/')}/book/#{setting.public_token}"
  end
end
