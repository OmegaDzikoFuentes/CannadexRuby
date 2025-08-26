# app/controllers/admin/strains_controller.rb
class Admin::StrainsController < Admin::ApplicationController
    before_action :find_strain, only: [:show, :update, :destroy, :verify, :toggle_active]
    
    def index
      strains = Strain.includes(:category, image_attachment: :blob)
                     .order(created_at: :desc)
                     .page(params[:page]).per(50)
      
      render json: {
        strains: strains.map { |s| admin_strain_data(s) },
        pagination: pagination_data(strains)
      }
    end
    
    def show
      render json: { strain: detailed_admin_strain_data(@strain) }
    end
    
    def update
      if @strain.update(admin_strain_params)
        render json: { strain: admin_strain_data(@strain), message: 'Strain updated successfully' }
      else
        render json: { errors: @strain.errors }, status: :unprocessable_entity
      end
    end
    
    def destroy
      @strain.destroy
      render json: { message: 'Strain deleted successfully' }
    end
    
    def verify
      @strain.update!(verified: true)
      render json: {
        strain: admin_strain_data(@strain),
        message: 'Strain verified'
      }
    end
    
    private
    
    def find_strain
      @strain = Strain.find(params[:id])
    end
    
    def admin_strain_params
      params.permit(:name, :description, :genetics, :thc_percentage, :cbd_percentage,
                    :verified, :category_id, effects: [], flavors: [], medical_uses: [])
    end
    
    def admin_strain_data(strain)
      {
        id: strain.id,
        name: strain.name,
        category: strain.category.name,
        genetics: strain.genetics,
        thc_percentage: strain.thc_percentage,
        cbd_percentage: strain.cbd_percentage,
        encounters_count: strain.encounters_count,
        average_rating: strain.average_overall_rating,
        verified: strain.verified?,
        data_source: strain.data_source,
        created_at: strain.created_at
      }
    end
    
    def detailed_admin_strain_data(strain)
      admin_strain_data(strain).merge({
        description: strain.description,
        effects: strain.effects,
        flavors: strain.flavors,
        medical_uses: strain.medical_uses,
        image_url: strain.image.attached? ? rails_blob_url(strain.image) : strain.image_url,
        recent_encounters_count: strain.encounters.where('created_at > ?', 30.days.ago).count,
        unique_users_count: strain.encounters.distinct.count(:user_id)
      })
    end
  end