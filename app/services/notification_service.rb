# app/services/notification_service.rb
class NotificationService
    def self.create_friend_request_notification(recipient, sender)
      # This would integrate with your notification system
      # For now, we'll just create an activity
      recipient.activities.create!(
        activity_type: 'friend_request_received',
        trackable: sender,
        data: { sender_username: sender.username }.to_json,
        public: false
      )
    end
    
    def self.create_battle_notification(recipient, battle, type)
      recipient.activities.create!(
        activity_type: "battle_#{type}",
        trackable: battle,
        data: {
          challenger_username: battle.challenger.username,
          opponent_username: battle.opponent.username,
          battle_id: battle.id
        }.to_json,
        public: type == 'won'
      )
    end
    
    def self.create_achievement_notification(user, achievement)
      user.activities.create!(
        activity_type: 'achievement_unlocked',
        trackable: achievement,
        data: {
          achievement_title: achievement.title,
          xp_earned: achievement.xp_reward
        }.to_json,
        public: true
      )
    end
  end