# app/models/activity.rb
class Activity < ApplicationRecord
    belongs_to :user
    belongs_to :trackable, polymorphic: true
    
    validates :activity_type, presence: true
    validates :trackable_type, :trackable_id, presence: true
    
    scope :public_activities, -> { where(public: true) }
    scope :recent, -> { order(created_at: :desc) }
    scope :for_user_feed, ->(user) {
      friend_ids = user.friends.pluck(:id)
      where(user_id: [user.id] + friend_ids, public: true)
    }
    
    def data_hash
      return {} unless data.present?
      JSON.parse(data) rescue {}
    end
    
    def formatted_message
      case activity_type
      when 'encounter_created'
        strain_name = trackable.strain.name rescue 'Unknown Strain'
        "added #{strain_name} to their Cannadex"
      when 'battle_won'
        opponent = data_hash['opponent_username'] || 'someone'
        score = data_hash['score'] || '3-0'
        "won a battle against #{opponent} (#{score})"
      when 'achievement_unlocked'
        title = data_hash['achievement_title'] || 'an achievement'
        "unlocked #{title}"
      else
        activity_type.humanize
      end
    end
  end
