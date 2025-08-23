# app/models/encounter.rb  
class Encounter < ApplicationRecord
    belongs_to :user
    belongs_to :strain
    has_many :activities, as: :trackable, dependent: :destroy
    
    # Active Storage for bud photos
    has_many_attached :photos
    
    validates :user_id, uniqueness: { scope: :strain_id, message: "can only have one encounter per strain" }
    validates :encountered_at, presence: true
    validates :taste_rating, :smell_rating, :texture_rating, :overall_rating, :potency_rating,
              inclusion: { in: 0..10 }
    
    scope :public_encounters, -> { where(public: true) }
    scope :friends_only, -> { where(friends_only: true) }
    scope :recent, -> { order(encountered_at: :desc) }
    scope :near_location, ->(lat, lng, radius_miles = 35) {
      where(
        "ST_DWithin(location, ST_SetSRID(ST_MakePoint(?, ?), 4326), ?)",
        lng, lat, radius_miles * 1609.34
      )
    }
    
    after_create :generate_digital_card, :create_activity, :update_user_stats, :check_achievements
    after_update :regenerate_digital_card, if: :saved_change_to_ratings?
    
    def average_rating
      (taste_rating + smell_rating + texture_rating + overall_rating + potency_rating) / 5.0
    end
    
    def location_coordinates
      return nil unless location
      [location.lat, location.lon]
    end
    
    def set_location(lat, lng)
      self.location = "POINT(#{lng} #{lat})"
    end
    
    def visible_to_user?(viewing_user)
      return true if user == viewing_user
      return true if public?
      return true if friends_only? && user.friends.include?(viewing_user)
      false
    end
    
    private
    
    def generate_digital_card
      GenerateDigitalCardJob.perform_later(self)
    end
    
    def regenerate_digital_card
      self.card_generated = false
      generate_digital_card
    end
    
    def saved_change_to_ratings?
      saved_change_to_taste_rating? || saved_change_to_smell_rating? || 
      saved_change_to_texture_rating? || saved_change_to_overall_rating? ||
      saved_change_to_potency_rating?
    end
    
    def create_activity
      activities.create!(
        user: user,
        activity_type: 'encounter_created',
        public: public?
      )
    end
    
    def update_user_stats
      user.increment!(:total_encounters)
      user.update_column(:experience_points, user.experience_points + 10)
      user.check_level_up!
    end
    
    def check_achievements
      CheckAchievementsJob.perform_later(user, 'encounter_created')
    end
  end