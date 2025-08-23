# app/models/strain.rb
class Strain < ApplicationRecord
    belongs_to :category, counter_cache: true
    has_many :encounters, dependent: :destroy
    has_many :users, through: :encounters
    has_many :battle_strains, dependent: :destroy
    has_many :battles, through: :battle_strains
    
    # Active Storage for strain images
    has_one_attached :image
    
    validates :name, presence: true, length: { maximum: 100 }, uniqueness: true
    validates :genetics, :data_source, presence: true
    validates :thc_percentage, :cbd_percentage, numericality: { 
      greater_than_or_equal_to: 0, less_than_or_equal_to: 100 
    }, allow_nil: true
    
    scope :verified, -> { where(verified: true) }
    scope :by_category, ->(category) { where(category: category) }
    scope :popular, -> { order(encounters_count: :desc) }
    scope :highly_rated, -> { where('average_overall_rating >= ?', 7.0) }
    
    before_save :calculate_average_ratings
    
    def dominant_type
      return 'Unknown' unless genetics.present?
      
      if genetics.include?('100%')
        genetics.include?('Indica') ? 'Indica' : 'Sativa'
      elsif genetics =~ /(\d+)%\s*Indica/
        indica_percent = $1.to_i
        indica_percent > 50 ? 'Indica Dominant' : 'Sativa Dominant'
      else
        'Hybrid'
      end
    end
    
    def effects_list
      effects || []
    end
    
    def flavors_list  
      flavors || []
    end
    
    private
    
    def calculate_average_ratings
      return unless encounters.any?
      
      self.average_taste_rating = encounters.average(:taste_rating).round(2)
      self.average_smell_rating = encounters.average(:smell_rating).round(2)  
      self.average_texture_rating = encounters.average(:texture_rating).round(2)
      self.average_overall_rating = encounters.average(:overall_rating).round(2)
    end
  end
  