# AI agent > "Fill from website": reads one public page of the business (its website, a Daraz/Shopify store page, a menu)
# and drafts the business name and business info. Nothing is saved: the draft goes into the form for the owner to check.
class Ai::WebsiteImporter
  class Error < StandardError; end

  MAX_BYTES = 3.megabytes
  MAX_TEXT = 15_000
  SYSTEM = 'You help small businesses in Pakistan set up a WhatsApp sales assistant. Reply with JSON only, no other text.'.freeze

  pattr_initialize [:agent!, :url!]

  def perform
    text = page_text
    raise Error, 'empty page' if text.length < 80

    reply = Ai::LlmClient.chat(system: SYSTEM, messages: [{ role: 'user', text: request_text(text) }], max_tokens: 2500, within: 30, fast: true)
    draft = parse(reply)
    raise Error, 'no business info' if draft['business_info'].blank?

    agent.account.increment_plan_usage!(:copilot_tasks)
    { business_name: draft['business_name'].to_s.truncate(120), business_info: draft['business_info'].to_s.truncate(8000) }
  end

  private

  def page_text
    html = SafeFetch.fetch(normalized_url, allowed_content_type_prefixes: ['text/'], allowed_content_types: ['application/xhtml+xml'],
                                           max_bytes: MAX_BYTES, read_timeout: 15) { |result| result.tempfile.read }
    doc = Nokogiri::HTML(html)
    doc.css('script, style, noscript, svg, iframe').remove
    meta = doc.at('meta[name="description"]')&.[]('content')
    [doc.title, meta, doc.at('body')&.text].compact.join("\n").squish.first(MAX_TEXT)
  rescue SafeFetch::Error => e
    raise Error, e.message
  end

  def normalized_url
    value = url.to_s.strip
    value.match?(%r{\Ahttps?://}i) ? value : "https://#{value}"
  end

  def request_text(text)
    <<~TEXT
      This is the text of the business's web page (#{normalized_url}):
      #{text}

      Write the business information the assistant will use to answer customers. Use plain English with short lines and
      sections such as: what we sell or offer, main products or services with prices if shown, delivery areas and charges,
      payment methods, timings, location and contact, returns or warranty. Only use facts from the page; skip what it does not say.
      Return JSON like {"business_name": "...", "business_info": "..."}.
    TEXT
  end

  def parse(reply)
    JSON.parse(reply[/\{.*\}/m].to_s)
  rescue JSON::ParserError
    {}
  end
end
