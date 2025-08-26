# app/services/user_recommendation_service.rb
class UserRecommendationService
    def self.similar_users(user, limit: 10)
      # Find users with similar strain preferences
      user_strains = user.encounters.includes(:strain).map(&:strain)
      return [] if user_strains.empty?
      
      # Get all other users who have tried similar strains
      potential_matches = User.joins(:encounters)
                             .where(encounters: { strain_id: user_strains.map(&:id) })
                             .where.not(id: user.id)
                             .where(profile_public: true)
                             .group('users.id')
                             .having('COUNT(DISTINCT encounters.strain_id) >= ?', [user_strains.size * 0.2, 2].max.to_i)
      
      recommendations = []
      
      potential_matches.find_each do |potential_match|
        match_strains = potential_match.encounters.includes(:strain).map(&:strain)
        common_strains = user_strains & match_strains
        
        next if common_strains.size < 2
        
        similarity_score = calculate_user_similarity(user, potential_match, common_strains)
        mutual_friends = (user.friends & potential_match.friends).size
        
        recommendations << {
          user: potential_match,
          similarity_score: similarity_score,
          common_strains: common_strains.size,
          mutual_friends: mutual_friends
        }
      end
      
      recommendations.sort_by { |r| [-r[:similarity_score], -r[:mutual_friends]] }
                    .first(limit)
    end
    
    private
    
    def self.calculate_user_similarity(user1, user2, common_strains)
      return 0 if common_strains.empty?
      
      similarity_sum = 0
      
      common_strains.each do |strain|
        user1_encounter = user1.encounters.find_by(strain: strain)
        user2_encounter = user2.encounters.find_by(strain: strain)
        
        next unless user1_encounter && user2_encounter
        
        rating_diff = (user1_encounter.overall_rating - user2_encounter.overall_rating).abs
        strain_similarity = 1 - (rating_diff / 10.0)
        similarity_sum += strain_similarity
      end
      
      (similarity_sum / common_strains.size).round(3)
    end
  end
  