# app/controllers/api/v1/recommendations_controller.rb
class Api::V1::RecommendationsController < Api::V1::ApplicationController
    def strains
      recommendations = StrainRecommendationService.recommendations_for_user(current_user)
      
      render_success({
        recommendations: recommendations.map { |r| recommendation_data(r) }
      })
    end
    
    def users
      # Find users with similar strain preferences
      similar_users = UserRecommendationService.similar_users(current_user)
      
      render_success({
        recommended_users: similar_users.map { |u| user_recommendation_data(u) }
      })
    end
    
    private
    
    def recommendation_data(recommendation)
      {
        strain: strain_summary(recommendation[:strain]),
        reason: recommendation[:reason],
        confidence_score: recommendation[:confidence_score],
        similar_strains: recommendation[:similar_strains]&.map { |s| strain_summary(s) }
      }
    end
    
    def user_recommendation_data(user_data)
      {
        user: user_summary(user_data[:user]),
        similarity_score: user_data[:similarity_score],
        common_strains: user_data[:common_strains],
        mutual_friends: user_data[:mutual_friends]
      }
    end
    
    def strain_summary(strain)
      {
        id: strain.id,
        name: strain.name,
        category: strain.category.name,
        genetics: strain.genetics,
        average_rating: strain.average_overall_rating,
        effects: strain.effects_list
      }
    end
    
    def user_summary(user)
      {
        id: user.id,
        username: user.username,
        level: user.level,
        total_encounters: user.total_encounters
      }
    end
  end