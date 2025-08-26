# app/services/community_stats_service.rb
class CommunityStatsService
    def self.generate_stats(user, radius_miles = 35)
      return {} unless user.location
      
      nearby_users = GeolocationService.nearby_users(user, radius_miles)
      nearby_encounters = GeolocationService.nearby_encounters(user, radius_miles)
      
      {
        location_info: {
          city: user.city,
          state: user.state,
          radius_miles: radius_miles
        },
        community: {
          nearby_users_count: nearby_users.count,
          total_encounters: nearby_encounters.count,
          active_this_month: nearby_encounters.where('created_at > ?', 1.month.ago).count
        },
        popular_strains: popular_strains_nearby(nearby_encounters),
        trending_effects: trending_effects_nearby(nearby_encounters),
        recent_discoveries: recent_discoveries_nearby(nearby_encounters),
        community_ratings: community_rating_trends(nearby_encounters)
      }
    end
    
    private
    
    def self.popular_strains_nearby(encounters)
      encounters.joins(:strain)
               .group('strains.name')
               .order('COUNT(*) DESC')
               .limit(10)
               .count
               .map { |strain_name, count| { name: strain_name, encounters: count } }
    end
    
    def self.trending_effects_nearby(encounters)
      effect_counts = Hash.new(0)
      
      encounters.where('created_at > ?', 1.month.ago)
               .where.not(effects_experienced: [])
               .find_each do |encounter|
        encounter.effects_experienced.each do |effect|
          effect_counts[effect] += 1
        end
      end
      
      effect_counts.sort_by { |effect, count| -count }.first(10).to_h
    end
    
    def self.recent_discoveries_nearby(encounters)
      encounters.joins(:strain)
               .where('encounters.created_at > ?', 1.week.ago)
               .group('strains.name')
               .having('COUNT(*) = 1')
               .order('encounters.created_at DESC')
               .limit(5)
               .pluck('strains.name', 'encounters.overall_rating', 'encounters.created_at')
               .map { |name, rating, created_at| 
                 { strain_name: name, rating: rating, discovered_at: created_at }
               }
    end
    
    def self.community_rating_trends(encounters)
      monthly_ratings = encounters.where('created_at > ?', 6.months.ago)
                                 .group_by_month(:created_at)
                                 .average(:overall_rating)
                                 .map { |month, avg_rating| 
                                   { month: month, average_rating: avg_rating&.round(2) }
                                 }
      
      {
        monthly_trends: monthly_ratings,
        current_average: encounters.where('created_at > ?', 1.month.ago)
                                  .average(:overall_rating)&.round(2)
      }
    end
  end
  