# app/models/banner_photo.rb
class BannerPhoto < ApplicationRecord
    has_one_attached :image
    
    validates :image_url, length: { maximum: 255 }
    validate :has_image_source
    
    scope :active, -> { where(active: true) }
    scope :recent, -> { order(created_at: :desc) }
    
    # Virtual attribute for active status (you might want to add this to schema)
    attr_accessor :active
    
    before_save :set_active_default
    
    def self.current_banner
      active.first || recent.first
    end
    
    def self.random_banner
      active.any? ? active.sample : recent.sample
    end
    
    def image_source_url
      if image.attached?
        Rails.application.routes.url_helpers.rails_blob_url(image, only_path: true)
      elsif image_url.present?
        image_url
      else
        '/assets/default-banner.jpg' # fallback
      end
    end
    
    def display_url
      image_source_url
    end
    
    def has_attached_image?
      image.attached?
    end
    
    def has_url_image?
      image_url.present?
    end
    
    def image_source_type
      return 'attached' if has_attached_image?
      return 'url' if has_url_image?
      'none'
    end
    
    # Method to activate this banner and deactivate others
    def activate!
      transaction do
        BannerPhoto.update_all(active: false) if respond_to?(:active)
        update!(active: true) if respond_to?(:active)
      end
    end
    
    def deactivate!
      update!(active: false) if respond_to?(:active)
    end
    
    private
    
    def has_image_source
      unless has_attached_image? || has_url_image?
        errors.add(:base, 'Must have either an attached image or image URL')
      end
    end
    
    def set_active_default
      # If this is the first banner photo, make it active by default
      if respond_to?(:active) && BannerPhoto.count == 0
        self.active = true
      end
    end
  end