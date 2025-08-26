# app/controllers/api/v1/strains_controller.rb
class Api::V1::StrainsController < Api::V1::ApplicationController
    before_action :find_strain, only: [:show, :community_stats, :similar]
    
    def index
      strains = Strain.includes(:category, image_attachment: :blob)
      
      # Apply filters
      strains = strains.where(category_id: params[:category_id]) if params[:category_id].present?
      strains = strains.verified if params[:verified] == 'true'
      strains = strains.where('thc_percentage >= ?', params[:min_thc]) if params[:min_thc].present?
      strains = strains.where('thc_percentage <= ?', params[:max_thc]) if params[:max_thc].present?
      strains = strains.where('average_overall_rating >= ?', params[:min_rating]) if params[:min_rating].present?
      
      # Apply sorting
      case params[:sort]
      when 'popular'
        strains = strains.order(encounters_count: :desc)
      when 'rating'
        strains = strains.order(average_overall_rating: :desc)
      when 'alphabetical'
        strains = strains.order(:name)
      when 'recent'
        strains = strains.order(created_at: :desc)
      else
        strains = strains.order(:name)
      end
      
      strains = strains.page(params[:page]).per(20)
      
      render_success({
        strains: strains.map { |s| strain_data(s) },
        pagination: pagination_data(strains)
      })
    end
    
    def show
      render_success({ 
        strain: detailed_strain_data(@strain),
        community_stats: community_stats_data(@strain)
      })
    end
    
    def search
      query = params[:q]&.strip
      return render_error('Search query required') if query.blank?
      
      strains = Strain.where('name ILIKE ? OR description ILIKE ?', "%#{query}%", "%#{query}%")
                     .includes(:category)
                     .limit(20)
      
      render_success({
        strains: strains.map { |s| strain_data(s) }
      })
    end
    
    def popular
      strains = Strain.includes(:category)
                     .where('encounters_count > 0')
                     .order(encounters_count: :desc, average_overall_rating: :desc)
                     .limit(20)
      
      render_success({
        strains: strains.map { |s| strain_data(s) }
      })
    end
    
    def recently_added
      strains = Strain.includes(:category)
                     .order(created_at: :desc)
                     .limit(20)
      
      render_success({
        strains: strains.map { |s| strain_data(s) }
      })
    end
    
    def community_stats
      stats = community_stats_data(@strain)
      
      # Get nearby community stats if user has location
      if current_user.location && params[:include_nearby] == 'true'
        nearby_encounters = GeolocationService.nearby_encounters_for_strain(
          current_user, @strain, params[:radius]&.to_i || 35
        )
        
        if nearby_encounters.any?
          stats[:nearby] = {
            total_encounters: nearby_encounters.count,
            average_rating: nearby_encounters.average(:overall_rating).round(2),
            rating_breakdown: rating_breakdown(nearby_encounters)
          }
        end
      end
      
      render_success({ community_stats: stats })
    end
    
    def similar
      similar_strains = StrainRecommendationService.similar_strains(@strain, limit: 10)
      
      render_success({
        similar_strains: similar_strains.map { |s| strain_data(s) }
      })
    end
    
    private
    
    def find_strain
      @strain = Strain.find(params[:id])
    end
    
    def strain_data(strain)
      {
        id: strain.id,
        name: strain.name,
        description: strain.description,
        image_url: strain.image.attached? ? rails_blob_url(strain.image) : strain.image_url,
        category: {
          id: strain.category.id,
          name: strain.category.name,
          category_type: strain.category.category_type
        },
        genetics: strain.genetics,
        dominant_type: strain.dominant_type,
        thc_percentage: strain.thc_percentage,
        cbd_percentage: strain.cbd_percentage,
        effects: strain.effects_list,
        flavors: strain.flavors_list,
        medical_uses: strain.medical_uses,
        ratings: {
          taste: strain.average_taste_rating,
          smell: strain.average_smell_rating,
          texture: strain.average_texture_rating,
          overall: strain.average_overall_rating
        },
        encounters_count: strain.encounters_count,
        verified: strain.verified?,
        data_source: strain.data_source,
        created_at: strain.created_at
      }
    end
    
    def detailed_strain_data(strain)
      data = strain_data(strain)
      
      # Add recent encounters if user has permission
      recent_encounters = strain.encounters
                               .joins(:user)
                               .where(users: { profile_public: true })
                               .or(strain.encounters.where(user: current_user.friends))
                               .includes(:user)
                               .order(encountered_at: :desc)
                               .limit(5)
      
      data[:recent_encounters] = recent_encounters.map do |encounter|
        {
          id: encounter.id,
          user: {
            id: encounter.user.id,
            username: encounter.user.username,
            level: encounter.user.level
          },
          overall_rating: encounter.overall_rating,
          description: encounter.description&.truncate(100),
          encountered_at: encounter.encountered_at
        }
      end
      
      data
    end
    
    def community_stats_data(strain)
      encounters = strain.encounters
      
      return {} if encounters.empty?
      
      {
        total_encounters: encounters.count,
        unique_users: encounters.distinct.count(:user_id),
        average_ratings: {
          taste: strain.average_taste_rating,
          smell: strain.average_smell_rating,
          texture: strain.average_texture_rating,
          overall: strain.average_overall_rating,
          potency: encounters.average(:potency_rating).round(2)
        },
        rating_distribution: {
          excellent: encounters.where('overall_rating >= 9').count,
          good: encounters.where('overall_rating >= 7 AND overall_rating < 9').count,
          average: encounters.where('overall_rating >= 5 AND overall_rating < 7').count,
          poor: encounters.where('overall_rating < 5').count
        },
        most_common_effects: most_common_effects(encounters),
        price_range: price_range(encounters)
      }
    end
    
    def most_common_effects(encounters)
      effect_counts = Hash.new(0)
      
      encounters.where.not(effects_experienced: []).find_each do |encounter|
        encounter.effects_experienced.each do |effect|
          effect_counts[effect] += 1
        end
      end
      
      effect_counts.sort_by { |effect, count| -count }.first(5).to_h
    end
    
    def price_range(encounters)
      prices = encounters.where.not(price_paid: nil).pluck(:price_paid)
      return {} if prices.empty?
      
      {
        min: prices.min,
        max: prices.max,
        average: (prices.sum / prices.size).round(2)
      }
    end
    
    def rating_breakdown(encounters)
      {
        taste: encounters.average(:taste_rating).round(2),
        smell: encounters.average(:smell_rating).round(2),
        texture: encounters.average(:texture_rating).round(2),
        overall: encounters.average(:overall_rating).round(2),
        potency: encounters.average(:potency_rating).round(2)
      }
    end
    
    def pagination_data(collection)
      {
        current_page: collection.current_page,
        total_pages: collection.total_pages,
        total_count: collection.total_count,
        per_page: collection.limit_value
      }
    end
  end