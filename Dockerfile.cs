FROM chatssync-custom:backup-2026-09-14
RUN rm -rf /app/public/vite
COPY --chown=1000:1000 public/vite /app/public/vite
COPY --chown=1000:1000 app/models/notification.rb /app/app/models/notification.rb
COPY --chown=1000:1000 app/javascript/dashboard/i18n/index.js /app/app/javascript/dashboard/i18n/index.js
COPY --chown=1000:1000 app/services/whatsapp/incoming_message_service_helpers.rb /app/app/services/whatsapp/incoming_message_service_helpers.rb
COPY --chown=1000:1000 app/services/whatsapp/incoming_message_base_service.rb /app/app/services/whatsapp/incoming_message_base_service.rb
COPY --chown=1000:1000 app/services/whatsapp/oneoff_campaign_service.rb /app/app/services/whatsapp/oneoff_campaign_service.rb
