# app/services/user_stats_service.rb
class UserStatsService
    def self.generate_stats(user)
      encounters = user.encounters.includes(:strain)
      
      {
        overview: {
          total_encounters: encounters.count,
          unique_strains: encounters.joins(:strain).distinct.count('strains.id'),
          average_rating: encounters.average(:overall_rating)&.round(2) || 0,
          favorite_effects: favorite_effects(encounters),
          most_common_genetics: most_common_genetics(encounters)
        },
        ratings: rating_stats(encounters),
        timeline: encounter_timeline(encounters),
        categories: category_breakdown(encounters),
        social: social_stats(user),
        achievements: achievement_stats(user),
        battles: battle_stats(user),
        recent_activity: recent_activity(user)
      }
    end
    
    private
    
    def self.favorite_effects(encounters)
      effect_counts = Hash.new(0)
      
      encounters.where.not(effects_experienced: []).find_each do |encounter|
        encounter.effects_experienced.each do |effect|
          effect_counts[effect] += 1
        end
      end
      
      effect_counts.sort_by { |effect, count| -count }.first(5).to_h
    end
    
    def self.most_common_genetics(encounters)
      genetics_counts = encounters.joins(:strain)
                                 .where.not(strains: { genetics: nil })
                                 .group('strains.genetics')
                                 .count
                                 .sort_by { |genetics, count| -count }
                                 .first(5)
                                 .to_h
      
      genetics_counts
    end
    
    def self.rating_stats(encounters)
      return {} if encounters.empty?
      
      {
        average_taste: encounters.average(:taste_rating)&.round(2),
        average_smell: encounters.average(:smell_rating)&.round(2),
        average_texture: encounters.average(:texture_rating)&.round(2),
        average_overall: encounters.average(:overall_rating)&.round(2),
        average_potency: encounters.average(:potency_rating)&.round(2),
        highest_rated: encounters.order(overall_rating: :desc).first&.strain&.name,
        lowest_rated: encounters.order(:overall_rating).first&.strain&.name,
        rating_distribution: {
          excellent: encounters.where('overall_rating >= 9').count,
          good: encounters.where('overall_rating >= 7 AND overall_rating < 9').count,
          average: encounters.where('overall_rating >= 5 AND overall_rating < 7').count,
          poor: encounters.where('overall_rating < 5').count
        }
      }
    end
    
    def self.encounter_timeline(encounters)
      encounters.group_by_month(:encountered_at, last: 12)
               .count
               .map { |month, count| { month: month, encounters: count } }
    end
    
    def self.category_breakdown(encounters)
      encounters.joins(strain: :category)
               .group('categories.name')
               .count
    end
    
    def self.social_stats(user)
      {
        friends_count: user.friends.count,
        pending_friend_requests: user.friendships.pending.count,
        incoming_friend_requests: Friendship.where(friend: user, status: 'pending').count
      }
    end
    
    def self.achievement_stats(user)
      achievements = user.achievements
      
      {
        total_unlocked: achievements.unlocked.count,
        total_available: achievements.count,
        unclaimed_count: achievements.unclaimed.count,
        total_xp_earned: achievements.unlocked.sum(:xp_reward),
        recent_unlocked: achievements.unlocked
                                   .order(unlocked_at: :desc)
                                   .limit(3)
                                   .map { |a| { title: a.title, unlocked_at: a.unlocked_at } }
      }
    end
    
    def self.battle_stats(user)
      {
        battles_won: user.battles_won,
        battles_lost: user.battles_lost,
        win_rate: user.win_rate,
        pending_battles: user.opponent_battles.pending.count,
        recent_battles: user.battles.completed
                           .order(battled_at: :desc)
                           .limit(5)
                           .map { |b| battle_summary(b, user) }
      }
    end
    
    def self.battle_summary(battle, user)
      opponent = battle.opponent_for(user)
      won = battle.winner == user
      
      {
        id: battle.id,
        opponent_username: opponent.username,
        won: won,
        score: won ? "#{battle.challenger_score}-#{battle.opponent_score}" : "#{battle.opponent_score}-#{battle.challenger_score}",
        battled_at: battle.battled_at
      }
    end
    
    def self.recent_activity(user)
      user.activities.includes(:trackable)
          .order(created_at: :desc)
          .limit(10)
          .map do |activity|
        {
          type: activity.activity_type,
          message: activity.formatted_message,
          created_at: activity.created_at
        }
      end
    end
  end