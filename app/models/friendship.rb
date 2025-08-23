# app/models/friendship.rb
class Friendship < ApplicationRecord
    belongs_to :user
    belongs_to :friend, class_name: 'User'
    
    validates :user_id, uniqueness: { scope: :friend_id }
    validates :status, inclusion: { in: %w[pending accepted blocked] }
    validate :cannot_friend_self
    
    scope :pending, -> { where(status: 'pending') }
    scope :accepted, -> { where(status: 'accepted') }
    scope :blocked, -> { where(status: 'blocked') }
    
    after_create :create_inverse_friendship, if: :accepted?
    after_update :handle_status_change
    
    def accept!
      return false unless pending?
      
      transaction do
        update!(status: 'accepted', accepted_at: Time.current)
        create_inverse_friendship unless inverse_friendship_exists?
        
        # Check friendship achievements for both users
        [user, friend].each do |u|
          CheckAchievementsJob.perform_later(u, 'friendship_created')
        end
      end
    end
    
    def block!
      update!(status: 'blocked')
      inverse_friendship&.update!(status: 'blocked')
    end
    
    def pending?
      status == 'pending'
    end
    
    def accepted?
      status == 'accepted'
    end
    
    def blocked?
      status == 'blocked'
    end
    
    private
    
    def cannot_friend_self
      errors.add(:friend, "can't friend yourself") if user_id == friend_id
    end
    
    def inverse_friendship_exists?
      Friendship.exists?(user: friend, friend: user)
    end
    
    def create_inverse_friendship
      return if inverse_friendship_exists?
      
      Friendship.create!(
        user: friend,
        friend: user,
        status: 'accepted',
        requested_at: Time.current,
        accepted_at: Time.current
      )
    end
    
    def handle_status_change
      return unless saved_change_to_status?
      
      case status
      when 'accepted'
        create_inverse_friendship unless inverse_friendship_exists?
      when 'blocked'
        inverse_friendship&.update!(status: 'blocked')
      end
    end
    
    def inverse_friendship
      Friendship.find_by(user: friend, friend: user)
    end
  end