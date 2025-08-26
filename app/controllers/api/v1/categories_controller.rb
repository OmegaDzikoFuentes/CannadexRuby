# app/controllers/api/v1/categories_controller.rb
class Api::V1::CategoriesController < Api::V1::ApplicationController
    def index
      categories = Category.active.includes(image_attachment: :blob)
      
      # Filter by category type if specified
      categories = categories.where(category_type: params[:type]) if params[:type].present?
      
      categories = categories.order(:name)
      
      render_success({
        categories: categories.map { |c| category_data(c) }
      })
    end
    
    def show
      category = Category.find(params[:id])
      
      # Get category stats
      stats = {
        total_strains: category.strains_count,
        verified_strains: category.strains.verified.count,
        total_encounters: Encounter.joins(:strain).where(strains: { category_id: category.id }).count,
        average_rating: category.strains.where('encounters_count > 0').average(:average_overall_rating)&.round(2)
      }
      
      # Get top strains in this category
      top_strains = category.strains
                           .includes(image_attachment: :blob)
                           .where('encounters_count > 0')
                           .order(average_overall_rating: :desc, encounters_count: :desc)
                           .limit(10)
      
      render_success({
        category: detailed_category_data(category),
        stats: stats,
        top_strains: top_strains.map { |s| strain_summary(s) }
      })
    end
    
    private
    
    def category_data(category)
      {
        id: category.id,
        name: category.name,
        description: category.description,
        category_type: category.category_type,
        image_url: category.image.attached? ? rails_blob_url(category.image) : category.image_url,
        strains_count: category.strains_count,
        active: category.active?
      }
    end
    
    def detailed_category_data(category)
      category_data(category)
    end
    
    def strain_summary(strain)
      {
        id: strain.id,
        name: strain.name,
        image_url: strain.image.attached? ? rails_blob_url(strain.image) : strain.image_url,
        genetics: strain.genetics,
        average_overall_rating: strain.average_overall_rating,
        encounters_count: strain.encounters_count,
        verified: strain.verified?
      }
    end
  end
  