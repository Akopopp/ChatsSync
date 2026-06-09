FROM chatwoot/chatwoot:latest

# Database ki tables load karne aur server chalane ki automatic command
CMD ["sh", "-c", "bundle exec rails db:prepare && bundle exec rails s -b 0.0.0.0 -p 3000"]
