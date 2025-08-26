class EncountersController < ApplicationController
    before_action :authenticate_user!
    before_action :set_encounter, only: [:show, :update, :destroy]
    before_action :ensure_own_encounter, only: [:update, :destroy]
  
    # GET /encounters
    def index
      @encounters = current_user.encounters.includes(:strain, :activities)
                               .order(encountered_at: :desc)
                               .page(params[:page]).per(20)
  
      render json: {
        encounters: @encounters.map { |e| encounter_json(e) },
        pagination: pagination_info(@encounters)
      }
    end
  
    # GET /encounters/:id
    def show
      render json: {
        encounter: detailed_encounter_json(@encounter),
        strain: strain_info(@encounter.strain),
        digital_card: @encounter.card_image_url if @encounter.card_generated
      }
    end
  
    # POST /encounters
    def create
      @strain = Strain.find_or_create_by!(name: encounter_params[:strain_name], category_id: encounter_params[:category_id])
      @encounter = current_user.encounters.build(encounter_params.except(:strain_name, :category_id).merge(strain_id: @strain.id))
  
      if @encounter.save
        GenerateDigitalCardJob.perform_later(@encounter.id)
  
        render json: {
          message: 'Encounter created successfully',
          encounter: encounter_json(@encounter)
        }, status: :created
      else
        render json: {
          error: 'Failed to create encounter',
          errors: @encounter.errors.full_messages
        }, status: :unprocessable_entity
      end
    end
  
    # PUT /encounters/:id
    def update
      if @encounter.update(encounter_update_params)
        @encounter.regenerate_digital_card if @encounter.saved_change_to_ratings?
  
        render json: {
          message: 'Encounter updated successfully',
          encounter: encounter_json(@encounter)
        }
      else
        render json: {
          error: 'Failed to update encounter',
          errors: @encounter.errors.full_messages
        }, status: :unprocessable_entity
      end
    end
  
    # DELETE /encounters/:id
    def destroy
      if @encounter.destroy
        render json: { message: 'Encounter deleted successfully' }
      else
        render json: { error: 'Failed to delete encounter' }, status: :unprocessable_entity
      end
    end
  
    # GET /encounters/map
    def map
      @encounters = current_user.encounters.where.not(location: nil)
                                        .order(encountered_at: :desc)
  
      render json: {
        locations: @encounters.map do |e|
          {
            id: e.id,
            latitude: e.location.lat,
            longitude: e.location.lon,
            strain_name: e.strain.name,
            encountered_at: e.encountered_at,
            rating: e.overall_rating
          }
        end
      }
    end
  
    private
  
    def set_encounter
      @encounter = Encounter.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      render json: { error: 'Encounter not found' }, status: :not_found
    end
  
    def ensure_own_encounter
      unless @encounter.user == current_user
        render json: { error: 'Not authorized' }, status: :forbidden
      end
    end
  
    def encounter_params
      params.require(:encounter).permit(
        :strain_name, :category_id, :taste_rating, :smell_rating,
        :texture_rating, :overall_rating, :potency_rating, :description,
        :experience, effects_experienced: [], location_name: [], source_type: [],
        source_name: [], price_paid: [], amount_purchased: [], public: [], friends_only: []
      )
    end
  
    def encounter_update_params
      params.require(:encounter).permit(
        :taste_rating, :smell_rating, :texture_rating,
        :overall_rating, :potency_rating, :description, :experience,
        effects_experienced: [], location_name: [], source_type: [],
        source_name: [], price_paid: [], amount_purchased: [], public: [], friends_only: []
      )
    end
  
    def encounter_json(encounter)
      {
        id: encounter.id,
        strain: strain_info(encounter.strain),
        ratings: {
          taste: encounter.taste_rating,
          smell: encounter.smell_rating,
          texture: encounter.texture_rating,
          overall: encounter.overall_rating,
          potency: encounter.potency_rating,
          average: encounter.average_rating
        },
        description: encounter.description,
        experience: encounter.experience,
        encountered_at: encounter.encountered_at,
        location: encounter.location_coordinates,
        public: encounter.public?,
        friends_only: encounter.friends_only?
      }
    end
  
    def detailed_encounter_json(encounter)
      encounter_json(encounter).merge(
        source_info: {
          type: encounter.source_type,
          name: encounter.source_name,
          price: encounter.price_paid,
          amount: encounter.amount_purchased
        },
        effects: encounter.effects_experienced,
        activities_count: encounter.activities.count
      )
    end
  
    def strain_info(strain)
      {
        id: strain.id,
        name: strain.name,
        category: strain.category.name,
        genetics: strain.genetics,
        average_rating: strain.average_overall_rating
      }
    end
  
    def pagination_info(collection)
      {
        current_page: collection.current_page,
        total_pages: collection.total_pages,
        total_count: collection.total_count
      }
    end
  end