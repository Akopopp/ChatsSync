# == Schema Information
#
# Table name: ai_knowledge_items
#
#  id         :bigint           not null, primary key
#  answer     :text
#  enabled    :boolean          default(TRUE), not null
#  kind       :string           default("faq"), not null
#  question   :text
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  account_id :bigint           not null
#
# Indexes
#
#  index_ai_knowledge_items_on_account_id_and_kind  (account_id,kind)
#
# A FAQ (question + answer) or a product picture/video (title + description) the AI can use.
# Media items keep the kind "image"; the attached file can be a picture or a video.
class AiKnowledgeItem < ApplicationRecord
  KINDS = %w[faq image].freeze
  # WhatsApp accepts pictures up to 5 MB and videos up to 16 MB.
  MAX_IMAGE_SIZE = 5.megabytes
  MAX_VIDEO_SIZE = 16.megabytes

  belongs_to :account
  has_one_attached :image

  validates :kind, inclusion: { in: KINDS }
  validates :question, presence: true, length: { maximum: 500 }
  validates :answer, length: { maximum: 2000 }
  validate :ensure_plan_knowledge_limit, on: :create
  validate :ensure_supported_media

  scope :enabled, -> { where(enabled: true) }
  scope :faqs, -> { where(kind: 'faq') }
  scope :images, -> { where(kind: 'image') }

  def image_url
    return nil unless image.attached?

    Rails.application.routes.url_helpers.url_for(image)
  end

  def video?
    image.attached? && image.blob.content_type.to_s.start_with?('video/')
  end

  private

  def ensure_supported_media
    return unless image.attached?

    type = image.blob.content_type.to_s
    if type.start_with?('video/')
      errors.add(:base, I18n.t('errors.ai.video_too_big')) if image.blob.byte_size > MAX_VIDEO_SIZE
    elsif type.start_with?('image/')
      errors.add(:base, I18n.t('errors.ai.image_too_big')) if image.blob.byte_size > MAX_IMAGE_SIZE
    else
      errors.add(:base, I18n.t('errors.ai.media_type'))
    end
  end

  def ensure_plan_knowledge_limit
    key = kind == 'image' ? :kb_files : :kb_faqs
    return if account.nil? || !account.plan_limit_reached?(key)

    errors.add(:base, I18n.t('errors.plan.knowledge_limit', limit: account.plan_limit(key)))
  end
end
