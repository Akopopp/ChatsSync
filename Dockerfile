FROM chatwoot/chatwoot:latest

# Railway ko force karne ke liye ke woh khud tables banaye aur server chalaye
CMD bundle exec rails db:schema:load db:seed && bundle exec rails s -b 0.0.0.0 -p 3000
