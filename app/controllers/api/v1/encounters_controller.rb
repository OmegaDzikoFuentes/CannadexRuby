# app/controllers/api/v1/encounters_controller.rb
class Api::V1::EncountersController < Api::V1::ApplicationController
    before_action :find_encounter, only: [:show, :update, :destroy, :regenerate_card, :toggle_privacy]
    
    def index
      encounters = current_user.encounters
                              .includes(:strain, :user, photos_attachments: :blob)
                              .order(encountered_at: :desc)
                              .page(params[:page])
                              .per(20)
      
      render_success({
        encounters: encounters.map { |e| encounter_data(e) },
        pagination: pagination_data(encounters)
      })
    end
    
    def show
      render_success({ encounter: encounter_data(@encounter) })
    end
    
    def create
      strain = find_or_create_strain
      return unless strain
      
      encounter = current_user.encounters.build(encounter_params.merge(strain: strain))
      
      if encounter.save
        attach_photos(encounter) if params[:photos].present?
        render_success({ encounter: encounter_data(encounter) }, 'Encounter created successfully')
      else
        render json: {
          success: false,
          message: 'Failed to create encounter',
          errors: encounter.errors
        }, status: :unprocessable_entity
      end
    end
    
    def update
      return render_unauthorized unless @encounter.user == current_user
      
      if @encounter.update(encounter_params)
        render_success({ encounter: encounter_data(@encounter) }, 'Encounter updated successfully')
      else
        render json: {
          success: false,
          message: 'Failed to update encounter',
          errors: @encounter.errors
        }, status: :unprocessable_entity
      end
    end
    
    def destroy
      return render_unauthorized unless @encounter.user == current_user
      
      @encounter.destroy
      render_success({}, 'Encounter deleted successfully')
    end
    
    def nearby
      return render_error('Location required') unless current_user.location
      
      encounters = GeolocationService.nearby_encounters(current_user, params[:radius]&.to_i || 35)
                                    .order(encountered_at: :desc)
                                    .page(params[:page])
                                    .per(20)
      
      render_success({
        encounters: encounters.map { |e| encounter_data(e, include_user: true) },
        pagination: pagination_data(encounters)
      })
    end
    
    def public_feed
      encounters = Encounter.public_encounters
                            .includes(:strain, :user, photos_attachments: :blob)
                            .order(encountered_at: :desc)
                            .page(params[:page])
                            .per(20)
      
      render_success({
        encounters: encounters.map { |e| encounter_data(e, include_user: true) },
        pagination: pagination_data(encounters)
      })
    end
    
    def friends_feed
      friend_ids = current_user.friends.pluck(:id)
      encounters = Encounter.where(user_id: friend_ids)
                            .where('public = ? OR friends_only = ?', true, true)
                            .includes(:strain, :user, photos_attachments: :blob)
                            .order(encountered_at: :desc)
                            .page(params[:page])
                            .per(20)
      
      render_success({
        encounters: encounters.map { |e| encounter_data(e, include_user: true) },
        pagination: pagination_data(encounters)
      })
    end
    
    def regenerate_card
      return render_unauthorized unless @encounter.user == current_user
      
      GenerateDigitalCardJob.perform_later(@encounter)
      render_success({}, 'Digital card regeneration started')
    end
    
    def toggle_privacy
      return render_unauthorized unless @encounter.user == current_user
      
      @encounter.update!(public: !@encounter.public?)
      render_success(
        { encounter: encounter_data(@encounter) },
        "Encounter is now #{@encounter.public? ? 'public' : 'private'}"
      )
    end
    
    private
    
    def find_encounter
      @encounter = Encounter.find(params[:id])
    end
    
    def encounter_params
      params.permit(
        :encountered_at, :taste_rating, :smell_rating, :texture_rating, 
        :overall_rating, :potency_rating, :description, :experience,
        :source_type, :source_name, :price_paid, :amount_purchased,
        :location_name, :public, :friends_only, :latitude, :longitude,
        effects_experienced: []
      )
    end
    
    def find_or_create_strain
      if params[:strain_id].present?
        Strain.find(params[:strain_id])
      elsif params[:strain_name].present?
        # Look for existing strain first
        strain = Strain.find_by("LOWER(name) = ?", params[:strain_name].downcase)
        
        # Create new strain if not found (user-contributed)
        unless strain
          category = Category.find_by(name: 'User Contributed') || Category.first
          strain = Strain.create!(
            name: params[:strain_name],
            category: category,
            data_source: 'user_contributed',
            verified: false
          )
        end
        
        strain
      else
        render_error('Strain ID or name required')
        nil
      end
    end
    
    def attach_photos(encounter)
      params[:photos].each do |photo|
        encounter.photos.attach(photo)
      end
    end
    
    def encounter_data(encounter, include_user: false)
      data = {
        id: encounter.id,
        strain: {
          id: encounter.strain.id,
          name: encounter.strain.name,
          category: encounter.strain.category.name,
          genetics: encounter.strain.genetics,
          average_rating: encounter.strain.average_overall_rating
        },
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
        effects_experienced: encounter.effects_experienced,
        location: {
          name: encounter.location_name,
          coordinates: encounter.location_coordinates
        },
        source: {
          type: encounter.source_type,
          name: encounter.source_name,
          price_paid: encounter.price_paid,
          amount_purchased: encounter.amount_purchased
        },
        privacy: {
          public: encounter.public?,
          friends_only: encounter.friends_only?
        },
        photos: encounter.photos.attached? ? encounter.photos.map { |photo| rails_blob_url(photo) } : [],
        card_image_url: encounter.card_image_url,
        card_generated: encounter.card_generated?,
        encountered_at: encounter.encountered_at,
        created_at: encounter.created_at,
        updated_at: encounter.updated_at
      }
      
      if include_user
        data[:user] = {
          id: encounter.user.id,
          username: encounter.user.username,
          level: encounter.user.level
        }
      end
      
      data
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
  