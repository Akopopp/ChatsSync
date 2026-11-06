# Smart features > "Find products from photos": when a customer sends a photo, the AI looks at it, offers the closest
# catalog items and shows their pictures. For a big catalog the photo is first turned into a few words,
# so the items most like it are the ones the AI gets to see.
module Ai::PhotoSearch
  RULE = <<~TEXT.freeze
    The customer sent a photo. If it shows a product, find the closest items in the catalog by type, colour, style
    and size, and offer up to 3 of them with their price and picture. Never invent a product that is not in the catalog.
    If nothing in the catalog is close, say so politely and offer what is similar.
  TEXT
  KEYWORDS_PROMPT = 'Describe the main product in the photo in 5 to 8 short English keywords (type, colour, material, style). ' \
                    'Reply with the keywords only, separated by spaces.'.freeze

  module_function

  def on?(account, images)
    images.any? && account.smart_feature_on?(:photo_search) && account.catalog_setting&.enabled == true
  end

  def catalog_question(account, question, images)
    return question if account.products.available.count <= Catalog::AiOrdering::MAX_PRODUCTS

    words = Ai::LlmClient.chat(system: KEYWORDS_PROMPT, messages: [{ role: 'user', text: 'What product is in this photo?' }],
                               images: images.first(1), max_tokens: 60, within: 15, fast: true)
    "#{question} #{words.to_s.squish.first(200)}"
  rescue Ai::LlmClient::Error
    question
  end
end
