# One item in an account's catalog or menu, with an optional picture the AI can send.
class Product < ApplicationRecord
  MAX_IMAGE_SIZE = 5.megabytes

  belongs_to :account
  has_one_attached :image

  validates :name, presence: true, length: { maximum: 120 }
  validates :description, length: { maximum: 1000 }
  validates :category, length: { maximum: 60 }
  validates :price, numericality: { greater_than_or_equal_to: 0 }
  validate :ensure_picture

  scope :available, -> { where(available: true) }
  scope :ordered, -> { order(:category, :position, :name) }

  def image_url
    return nil unless image.attached?

    Rails.application.routes.url_helpers.url_for(image)
  end

  # The AI reply sends product pictures the same way as AI product media.
  def video?
    false
  end

  private

  def ensure_picture
    return unless image.attached?

    errors.add(:base, I18n.t('errors.ai.media_type')) unless image.blob.content_type.to_s.start_with?('image/')
    errors.add(:base, I18n.t('errors.ai.image_too_big')) if image.blob.byte_size > MAX_IMAGE_SIZE
  end
end
