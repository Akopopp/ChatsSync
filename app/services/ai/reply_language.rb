# Works out which language the AI should reply in.
# A request like "urdu me bat kro" or "English samajh nahi aati" wins, then the latest message,
# then the language the customer has been writing in.
module Ai::ReplyLanguage
  # Common chat spellings too. Words that are also English (he, me, the, kal, bad) are left out.
  ROMAN_URDU_WORDS = %w[hai hain hy hn kya kia ki ka ke ko mein main nahi nahin nhi nai aap ap apka apki apke apko kitne kitna
                        kitni chahiye chaiye chahta chahti milega milegi bhej bhejo karna krna karni krni kar kr karo kro kardo krdo
                        karun krun kru krte krta krti hoga hogi hota hoti hogya gaya gya kaise kese kse kesy kab kahan yahan wahan
                        yeh ye wo woh tha thi bhai bhi aur ya muje mujhe mjhe mujse mujhse hamein humein mera meri mere uska uski
                        iska iski btao batao bta bata btana batana samj samajh smjh ati aati aata ata raha rha rahi rhi rahe rhe
                        pehle phle baad liye sath saath sirf zara thik theek acha achha accha haan jee ji kyun kyu kaun kon abhi aaj].freeze
  # "na" is left out: in Roman Urdu it is also a filler ("urdu me bat kro na").
  NEGATION = /\b(nahi|nahin|nhi|nai|not|no|don'?t|dont|cannot|can'?t)\b/i

  module_function

  # :urdu_script, :roman_urdu, :english, or nil when unclear. earlier: the customer's earlier messages.
  def detect(query, earlier = '')
    return :urdu_script if query.to_s.match?(/[؀-ۿ]/)

    requested("#{earlier}\n#{query}") || written(query) || written(earlier)
  end

  def roman_urdu?(text)
    words = text.to_s.downcase.scan(/[a-z]+/)
    words.present? && (words & ROMAN_URDU_WORDS).size >= [1, words.size / 6].max
  end

  # The latest line that names a language: "urdu me bat kro" -> Roman Urdu,
  # "English samj nhi ati" -> Roman Urdu, "reply in English" -> English.
  def requested(text)
    line = text.to_s.lines.reverse.find { |item| item.match?(/\b(urdu|english|angrezi)\b/i) }
    return if line.nil?

    wants_urdu = line.match?(/\burdu\b/i)
    wants_urdu = !wants_urdu if line.match?(NEGATION)
    wants_urdu ? :roman_urdu : :english
  end

  def written(text)
    return :roman_urdu if roman_urdu?(text)

    :english if text.to_s.scan(/[a-zA-Z]+/).size >= 3
  end
end
