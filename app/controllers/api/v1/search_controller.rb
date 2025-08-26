# app/controllers/api/v1/search_controller.rb
class Api::V1::SearchController < Api::V1::ApplicationController
    def index
      query = params[:q]&.strip
      return render_error('Search query required') if query.blank?
      
      results = {
        strains: search_strains(query),
        users: search_users(query)
      }
      
      render_success({ results: results })
    end
    
    def strains
      query = params[:q]&.strip
      return render_error('Search query required') if query.blank?
      
      strains = search_strains(query, limit: 50)
      
      render_success({ strains: strains })
    end
    
    def users
      query = params[:q]&.strip
      return render_error('Search query required') if query.blank?
      
      users = search_users(query, limit: 50)
      
      render_success({ users: users })
    end
    
    private
    
    def search_strains(query, limit: 10)
      Strain.where('name ILIKE ? OR description ILIKE ?', "%#{query}%", "%#{query}%")
            .includes(:category, image_attachment: :blob)
            .limit(limit)
            .map { |s| strain_summary(s) }
    end
    
    def search_users(query, limit: 10)
      User.where('username ILIKE ? OR first_name ILIKE ? OR last_name ILIKE ?', 
                 "%#{query}%", "%#{query}%", "%#{query}%")
          .where(discoverable_by_username: true, profile_public: true)
          .where.not(id: current_user.id)
          .limit(limit)
          .map { |u| user_summary(u) }
    end
    
    def strain_summary(strain)
      {
        id: strain.id,
        name: strain.name,
        category: strain.category.name,
        image_url: strain.image.attached? ? rails_blob_url(strain.image) : strain.image_url,
        genetics: strain.genetics,
        average_rating: strain.average_overall_rating,
        encounters_count: strain.encounters_count,
        verified: strain.verified?
      }
    end
    
    def user_summary(user)
      {
        id: user.id,
        username: user.username,
        full_name: user.full_name,
        level: user.level,
        total_encounters: user.total_encounters,
        battles_won: user.battles_won
      }
    end
  end
  