# Link to the account's public menu / catalog page.
module Catalog::PublicLink
  def self.url(setting)
    return if setting&.public_token.blank?

    "#{ENV.fetch('FRONTEND_URL', '').chomp('/')}/menu/#{setting.public_token}"
  end
end
