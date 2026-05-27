# app/jobs/analyze_photo_job.rb
#
# Background job that runs the full AI identification pipeline for a photo.
#
# Flow:
#   1. Load photo, guard against double-processing
#   2. Create a StrainIdentification record (attempt tracking)
#   3. Mark photo as processing
#   4. Call AiIdentificationService
#   5. Call StrainIdentification#process! with result
#   6. Notify user
#   7. On failure: retry with backoff, then mark failed after max attempts
#
# Enqueued automatically by Photo#after_create via Photo#enqueue_analysis
# Can also be manually retried: AnalyzePhotoJob.perform_later(photo_id)

class AnalyzePhotoJob < ApplicationJob
    queue_as :ai_analysis
  
    # Sidekiq retry configuration
    # Retries: 0s, 18s, 5m, 17m, 46m, ~2h, ~5h ... (exponential backoff)
    sidekiq_options retry: Photo::MAX_ANALYSIS_ATTEMPTS, dead: true
  
    # Discard if the photo no longer exists (deleted by user before job ran)
    discard_on ActiveRecord::RecordNotFound
  
    # Don't retry on permanent model errors — let it go to failed state
    discard_on AiIdentificationService::ParseError do |job, error|
      Rails.logger.error "[AnalyzePhotoJob] Parse error (discarding): #{error.message}"
      photo = Photo.find_by(id: job.arguments.first)
      photo&.fail_analysis!
      create_failed_identification(photo, error)
    end
  
    # Rate limit — retry after a longer wait
    retry_on AiIdentificationService::RateLimitError,
             wait: 5.minutes,
             attempts: 5
  
    # S3 issues — retry quickly
    retry_on S3Service::Error,
             wait: :exponentially_longer,
             attempts: 3
  
    # -------------------------------------------------------------------------
  
    def perform(photo_id)
      photo = Photo.find(photo_id)
  
      # Guard: don't re-run if already complete or actively processing by another worker
      if photo.analysis_complete?
        Rails.logger.info "[AnalyzePhotoJob] Photo #{photo_id} already complete, skipping"
        return
      end
  
      if photo.analysis_status == 'processing' && photo.analysis_attempts >= Photo::MAX_ANALYSIS_ATTEMPTS
        Rails.logger.warn "[AnalyzePhotoJob] Photo #{photo_id} exceeded max attempts, marking failed"
        photo.update!(analysis_status: 'failed')
        return
      end
  
      # Determine attempt number
      attempt_number = photo.analysis_attempts + 1
  
      # Create or find StrainIdentification for this attempt
      identification = StrainIdentification.find_or_initialize_by(
        photo: photo,
        attempt_number: attempt_number
      )
      identification.assign_attributes(
        user:   photo.user,
        status: 'processing'
      )
      identification.save!
  
      # Mark photo as processing
      photo.mark_analysis_processing!
  
      Rails.logger.info "[AnalyzePhotoJob] Starting analysis for photo #{photo_id} (attempt #{attempt_number})"
  
      # Run AI analysis
      result = AiIdentificationService.call(photo)
  
      if result.success?
        handle_success(photo, identification, result)
      else
        handle_failure(photo, identification, result.error)
      end
    end
  
    private
  
    def handle_success(photo, identification, result)
      identification.process!(
        model_response:  result.model_response,
        candidates:      result.candidates.map(&:stringify_keys),
        visual_features: result.visual_features.transform_keys(&:to_s),
        model_name:      result.model_name,
        model_version:   result.model_version,
        processing_ms:   result.processing_ms
      )
  
      Rails.logger.info(
        "[AnalyzePhotoJob] Photo #{photo.id} → status: #{identification.status}, " \
        "top: #{identification.top_candidate&.dig('strain_name')} " \
        "(#{identification.confidence_percent}%)"
      )
  
      notify_user(photo, identification)
      trigger_downstream_jobs(photo, identification)
    end
  
    def handle_failure(photo, identification, error_code)
      Rails.logger.error "[AnalyzePhotoJob] Analysis failed for photo #{photo.id}: #{error_code}"
      identification.fail!(error_code: error_code)
  
      if photo.retryable?
        Rails.logger.info "[AnalyzePhotoJob] Photo #{photo.id} is retryable, will retry via Sidekiq backoff"
        raise AiIdentificationService::ModelError, "Analysis failed: #{error_code}"
      else
        Rails.logger.error "[AnalyzePhotoJob] Photo #{photo.id} exhausted retries"
        notify_user_of_failure(photo)
      end
    end
  
    def notify_user(photo, identification)
      user = photo.user
  
      case identification.status
      when 'matched'
        strain_name = identification.matched_strain&.name || identification.top_candidate&.dig('strain_name')
        Notification.deliver_to(
          user,
          type:       'system',
          title:      "Strain identified: #{strain_name} 🌿",
          body:       "We identified your bud with #{identification.confidence_percent}% confidence. " \
                      "Tap to confirm or choose a different strain.",
          notifiable: identification,
          data: {
            photo_id:           photo.id,
            identification_id:  identification.id,
            strain_name:        strain_name,
            confidence:         identification.confidence
          }
        )
      when 'low_confidence'
        Notification.deliver_to(
          user,
          type:       'system',
          title:      "We think we found your strain — can you confirm?",
          body:       "We're not fully certain. Tap to review the top candidates.",
          notifiable: identification,
          data: {
            photo_id:          photo.id,
            identification_id: identification.id,
            top_candidates:    identification.candidates.first(3)
          }
        )
      when 'unmatched'
        Notification.deliver_to(
          user,
          type:       'system',
          title:      "Couldn't identify this strain",
          body:       "We couldn't match this bud to a known strain. Tap to select one manually.",
          notifiable: identification,
          data: {
            photo_id:          photo.id,
            identification_id: identification.id
          }
        )
      end
    end
  
    def notify_user_of_failure(photo)
      Notification.deliver_to(
        photo.user,
        type:       'system',
        title:      "Strain identification failed",
        body:       "We couldn't analyze this photo. Please try uploading a clearer image.",
        notifiable: photo,
        data:       { photo_id: photo.id }
      )
    end
  
    def trigger_downstream_jobs(photo, identification)
      # Generate the digital encounter card now that we have a strain ID
      if identification.confirmed? && photo.encounter
        GenerateDigitalCardJob.perform_later(photo.encounter)
      end
  
      # Check achievements triggered by a new identification
      if identification.status.in?(%w[matched user_confirmed])
        CheckAchievementsJob.perform_later(photo.user, 'strain_identified')
      end
    end
  
    def self.create_failed_identification(photo, error)
      return unless photo
      identification = StrainIdentification.find_or_initialize_by(
        photo: photo,
        attempt_number: photo.analysis_attempts
      )
      identification.fail!(error_class: error.class.name, error_message: error.message)
    end
  end