FROM chatwoot/chatwoot:v3.11.0

EXPOSE 3000

CMD rm -f tmp/pids/server.pid && \
    bundle exec rails db:chatwoot_prepare && \
    bundle exec rails s -b 0.0.0.0 -p 3000
