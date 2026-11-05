# ChatsSync: let the mobile app sign in.
# Stock cors.rb covers /api/* via ENABLE_API_CORS, but not /auth/*.
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins 'https://localhost', 'http://localhost', 'capacitor://localhost'
    resource '/auth/*',
             headers: :any,
             methods: %i[post options],
             expose: %w[access-token client uid expiry]
  end
end
