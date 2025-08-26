# app/services/strain_recommendation_service.rb
class StrainRecommendationService
    def self.recommendations_for_user(user, limit: 10)
      # Get user's highly rated strains to find similar ones
      liked_strains = user.encounters.where('overall_rating >= 8').includes(:strain).map(&:strain)
      
      return [] if liked_strains.empty?
      
      recommendations = []
      
      liked_strains.each do |strain|
        similar = similar_strains(strain, limit: 3)
        similar.each do |similar_strain|
          next if user.strains.include?(similar_strain)
          
          recommendations << {
            strain: similar_strain,
            reason: "Similar to #{strain.name} which you rated highly",
            confidence_score: calculate_similarity_score(strain, similar_strain),
            similar_strains: [strain]
          }
        end
      end
      
      recommendations.sort_by { |r| -r[:confidence_score] }.first(limit)
    end
    
    def self.similar_strains(strain, limit: 10)
      # Find strains with similar effects and genetics
      similar_by_effects = Strain.where.not(id: strain.id)
                                .where('effects && ARRAY[?]::text[]', strain.effects)
                                .where(category: strain.category)
      
      # Score by number of matching effects
      similar_by_effects.sort_by do |s|
        -(strain.effects & s.effects).size
      end.first(limit)
    end
    
    private
    
    def self.calculate_similarity_score(strain1, strain2)
      score = 0
      
      # Effects similarity (40% weight)
      common_effects = strain1.effects & strain2.effects
      score += (common_effects.size.to_f / [strain1.effects.size, strain2.effects.size].max) * 0.4
      
      # Genetics similarity (30% weight)
      if strain1.genetics == strain2.genetics
        score += 0.3
      elsif strain1.dominant_type == strain2.dominant_type
        score += 0.15
      end
      
      # Category similarity (20% weight)
      score += 0.2 if strain1.category == strain2.category
      
      # Rating similarity (10% weight)
      rating_diff = (strain1.average_overall_rating - strain2.average_overall_rating).abs
      score += (1 - rating_diff / 10.0) * 0.1
      
      score.round(3)
    end
  end
  