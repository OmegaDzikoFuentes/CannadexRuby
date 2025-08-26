# app/jobs/check_achievements_job.rb
class CheckAchievementsJob < ApplicationJob
    queue_as :default
    
    def perform(user, trigger_event)
      case trigger_event
      when 'encounter_created'
        check_encounter_achievements(user)
      when 'battle_completed'
        check_battle_achievements(user)
      when 'friendship_created'
        check_social_achievements(user)
      end
    end
    
    private
    
    def check_encounter_achievements(user)
      # First encounter achievement
      if user.total_encounters == 1
        achievement = user.achievements.find_by(achievement_type: 'first_encounter')
        achievement&.add_progress!(1)
      end
      
      # Strain collector achievement
      unique_strains_count = user.encounters.joins(:strain).distinct.count('strains.id')
      strain_collector = user.achievements.find_by(achievement_type: 'strain_collector')
      if strain_collector && unique_strains_count > strain_collector.progress
        strain_collector.update!(progress: unique_strains_count)
        strain_collector.add_progress!(0) # Check if goal reached
      end
      
      # Explorer achievement (different cities)
      cities_count = user.encounters.where.not(location_name: nil)
                        .distinct.count(:location_name)
      explorer = user.achievements.find_by(achievement_type: 'explorer')
      if explorer && cities_count > explorer.progress
        explorer.update!(progress: cities_count)
        explorer.add_progress!(0) # Check if goal reached
      end
      
      # Connoisseur achievement (rated strains)
      rated_strains = user.encounters.where('overall_rating > 0').count
      connoisseur = user.achievements.find_by(achievement_type: 'connoisseur')
      if connoisseur && rated_strains > connoisseur.progress
        connoisseur.update!(progress: rated_strains)
        connoisseur.add_progress!(0) # Check if goal reached
      end
    end
    
    def check_battle_achievements(user)
      # Battle rookie achievement
      if user.battles_won == 1
        achievement = user.achievements.find_by(achievement_type: 'battle_rookie')
        achievement&.add_progress!(1)
      end
    end
    
    def check_social_achievements(user)
      # Social butterfly achievement
      friends_count = user.friends.count
      social_butterfly = user.achievements.find_by(achievement_type: 'social_butterfly')
      if social_butterfly && friends_count > social_butterfly.progress
        social_butterfly.update!(progress: friends_count)
        social_butterfly.add_progress!(0) # Check if goal reached
      end
    end
  end