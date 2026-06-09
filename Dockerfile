FROM chatwoot/chatwoot:v3.11.1

# Database migrations aur seed load automatic chalane ke liye
CMD ["sh", "-c", "bundle exec rails db:prepare && bundle exec rails s -b 0.0.0.0 -p 3000"]
