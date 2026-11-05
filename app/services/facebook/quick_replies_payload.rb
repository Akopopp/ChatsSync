# Text payload for Messenger and Instagram, with chatbot options as quick replies.
# Quick replies allow 13 options of 20 characters; a longer menu goes out as a numbered list,
# and the chatbot takes the number as the answer.
module Facebook::QuickRepliesPayload
  MAX_QUICK_REPLIES = 13
  MAX_TITLE_LENGTH = 20

  private

  def text_message_payload
    titles = option_titles
    return { text: message.outgoing_content } if titles.empty?
    return { text: message.content, quick_replies: titles.map { |title| quick_reply(title) } } if quick_replies_fit?(titles)

    { text: [message.content.to_s.strip.presence, numbered_list(titles)].compact.join("\n\n") }
  end

  def option_titles
    return [] unless message.content_type == 'input_select'

    Array(message.content_attributes['items']).filter_map { |item| item['title'].presence }
  end

  def quick_replies_fit?(titles)
    titles.size <= MAX_QUICK_REPLIES && titles.all? { |title| title.length <= MAX_TITLE_LENGTH }
  end

  def quick_reply(title)
    { content_type: 'text', payload: title, title: title }
  end

  def numbered_list(titles)
    titles.each_with_index.map { |title, index| "#{index + 1}. #{title}" }.join("\n")
  end
end
