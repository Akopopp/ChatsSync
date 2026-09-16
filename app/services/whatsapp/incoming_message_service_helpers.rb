=====================================================================
  FEP — QADAM 1 (sirf LOG)
  file: app/services/whatsapp/incoming_message_service_helpers.rb
=====================================================================

Is method ko dhoondo:

  def conversation_params
    {
      account_id: @inbox.account_id,
      inbox_id: @inbox.id,
      contact_id: @contact.id,
      contact_inbox_id: @contact_inbox.id
    }
  end

Aur POORA is se replace kar do:

  # FEP (Free Entry Point) — qadam 1: sirf dekhna.
  #
  # Meta "muft conversation" ke liye alag se koi jhanda nahi bhejta.
  # Uska pata `referral` object se chalta hai, jo SIRF us pehle message
  # ke saath aata hai jo kisi ad (Click-to-WhatsApp) ya FB/IG button se
  # aaya ho. Chatwoot usay bilkul nazarandaaz karta hai.
  #
  # Abhi hum sirf log kar rahe hain taake ad se aane wale asli message
  # par dekh sakein ke `referral` waqai aata hai aur uski shakl kya hai.
  # Us ke baad hi asal feature banega (hara/laal dot). Andaaza laga kar
  # banate to shayad chalta hi nahi aur pata bhi na chalta.
  #
  # Ye sirf ek Rails.logger line hai — kisi cheez ko badalti nahi.
  def conversation_params
    log_fep_referral

    {
      account_id: @inbox.account_id,
      inbox_id: @inbox.id,
      contact_id: @contact.id,
      contact_inbox_id: @contact_inbox.id
    }
  end

  def log_fep_referral
    msg = messages_data&.first
    return if msg.blank?

    referral = msg[:referral] || msg['referral']
    Rails.logger.info(
      "[CHATSSYNC_FEP] inbox=#{@inbox.id} " \
      "has_referral=#{referral.present?} " \
      "referral=#{referral.inspect} " \
      "msg_keys=#{msg.keys.inspect}"
    )
  rescue StandardError => e
    Rails.logger.info("[CHATSSYNC_FEP] log failed: #{e.message}")
  end

=====================================================================
  DEPLOY KE BAAD KYA KARNA HAI
=====================================================================

1. Apne kisi Facebook/Instagram ad ya WhatsApp button se ek test
   message bhejwao (naye number se, taake nayi conversation bane).

2. Phir ye chalao:

   docker logs --tail 300 chatwoot-jtleh02u2c011t7rkczemi12-<naya-id> 2>&1 | grep CHATSSYNC_FEP

   (container ka poora naam: docker ps | grep jtleh)

3. Output mein dekhna:
     has_referral=true   -> referral aata hai. Uski shakl bhej dena,
                            phir asal feature bana denge.
     has_referral=false  -> referral nahi aa raha. Phir doosra rasta
                            dhoondna paRega (msg_keys se pata chalega
                            ke Meta kya kya bhejta hai).

4. Aam message (bina ad ke) par bhi ek baar dekh lena — us par
   has_referral=false hona chahiye. Us se pata chalega ke farq
   waqai referral se aa raha hai.
