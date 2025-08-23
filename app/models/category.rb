# app/models/category.rb
class Category < ApplicationRecord
    has_many :strains, dependent: :destroy
    has_one_attached :image
    
    validates :name, presence: true, length: { maximum: 25 }
    validates :category_type, inclusion: { in: %w[strain_type effect flavor_profile] }
    
    scope :active, -> { where(active: true) }
    scope :strain_types, -> { where(category_type: 'strain_type') }
    scope :effects, -> { where(category_type: 'effect') }
    scope :flavor_profiles, -> { where(category_type: 'flavor_profile') }
    
    def self.default_strain_types
      ['Indica', 'Sativa', 'Hybrid', 'CBD', 'Unknown']
    end
  end
