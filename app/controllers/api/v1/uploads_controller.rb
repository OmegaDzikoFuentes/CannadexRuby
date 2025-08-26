# app/controllers/api/v1/uploads_controller.rb
class Api::V1::UploadsController < Api::V1::ApplicationController
    def encounter_photos
      encounter = current_user.encounters.find(params[:encounter_id])
      
      if params[:photos].present?
        uploaded_photos = []
        
        params[:photos].each do |photo|
          encounter.photos.attach(photo)
          uploaded_photos << {
            id: encounter.photos.last.id,
            url: rails_blob_url(encounter.photos.last)
          }
        end
        
        # Regenerate digital card if this is the first photo
        if encounter.photos.count == uploaded_photos.count
          GenerateDigitalCardJob.perform_later(encounter)
        end
        
        render_success(
          { photos: uploaded_photos },
          'Photos uploaded successfully'
        )
      else
        render_error('No photos provided')
      end
    end
    
    def avatar
      if params[:avatar].present?
        current_user.avatar.attach(params[:avatar])
        
        render_success(
          { avatar_url: rails_blob_url(current_user.avatar) },
          'Avatar updated successfully'
        )
      else
        render_error('No avatar provided')
      end
    end
  end