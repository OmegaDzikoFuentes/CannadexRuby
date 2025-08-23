# app/models/app_info.rb
class AppInfo < ApplicationRecord
    has_one_attached :logo
    
    validates :name, presence: true, length: { maximum: 100 }
    validates :tagline, length: { maximum: 200 }
    validates :logo_url, length: { maximum: 225 }
    
    # Singleton pattern - only one AppInfo record should exist
    validate :only_one_app_info_allowed
    
    def self.current
      first_or_create(
        name: 'Cannadex',
        tagline: 'Your personal cannabis companion',
        about_text: 'Discover, catalog, and battle with your favorite strains.'
      )
    end
    
    def self.app_name
      current.name
    end
    
    def self.app_tagline
      current.tagline
    end
    
    def self.app_about
      current.about_text
    end
    
    def self.app_logo_url
      current.logo_url
    end
    
    def logo_image_url
      if logo.attached?
        Rails.application.routes.url_helpers.rails_blob_url(logo, only_path: true)
      elsif logo_url.present?
        logo_url
      else
        '/assets/cannadex-logo.png' # fallback
      end
    end
    
    def display_name
      name.presence || 'Cannadex'
    end
    
    def display_tagline
      tagline.presence || 'Your personal cannabis companion'
    end
    
    def display_about
      about_text.presence || 'Discover, catalog, and battle with your favorite strains in the ultimate cannabis social platform.'
    end
    
    private
    
    def only_one_app_info_allowed
      if AppInfo.count > 0 && persisted? == false
        errors.add(:base, 'Only one AppInfo record is allowed')
      elsif AppInfo.count > 1 && persisted?
        errors.add(:base, 'Only one AppInfo record is allowed') unless AppInfo.first == self
      end
    end
  end
  
