# app/controllers/admin/encounters_controller.rb
class Admin::EncountersController < Admin::ApplicationController
    load_and_authorize_resource
    def index
      encounters = Encounter.includes(:user, :strain)
                           .order(created_at: :desc)
                           .page(params[:page]).per(50)
      
      render json: {
        encounters: encounters.map { |e| admin_encounter_data(e) },
        pagination: pagination_data(encounters)
      }
    end
    
    def show
      encounter = Encounter.find(params[:id])
      render json: { encounter: detailed_admin_encounter_data(encounter) }
    end
    
    def destroy
      encounter = Encounter.find(params[:id])
      encounter.destroy
      render json: { message: 'Encounter deleted successfully' }
    end
    
    private
    
    def admin_encounter_data(encounter)
      {
        id: encounter.id,
        user: {
          id: encounter.user.id,
          username: encounter.user.username
        },
        strain: {
          id: encounter.strain.id,
          name: encounter.strain.name
        },
        overall_rating: encounter.overall_rating,
        public: encounter.public?,
        encountered_at: encounter.encountered_at,
        created_at: encounter.created_at
      }
    end
    
    def detailed_admin_encounter_data(encounter)
      admin_encounter_data(encounter).merge({
        ratings: {
          taste: encounter.taste_rating,
          smell: encounter.smell_rating,
          texture: encounter.texture_rating,
          potency: encounter.potency_rating
        },
        description: encounter.description,
        experience: encounter.experience,
        effects_experienced: encounter.effects_experienced,
        location_name: encounter.location_name,
        source_type: encounter.source_type,
        source_name: encounter.source_name,
        price_paid: encounter.price_paid,
        photos_count: encounter.photos.count
      })
    end
  end
  
