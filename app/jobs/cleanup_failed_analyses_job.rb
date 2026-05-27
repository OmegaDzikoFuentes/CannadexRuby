# app/jobs/cleanup_failed_analyses_job.rb
#
# Finds photos with failed analysis that are still retryable and re-enqueues them.
 
class CleanupFailedAnalysesJob < ApplicationJob
    queue_as :low
   
    def perform
      retryable = Photo.retryable
   
      Rails.logger.info "[CleanupFailedAnalysesJob] Re-enqueuing #{retryable.count} retryable photos"
   
      retryable.find_each do |photo|
        AnalyzePhotoJob.perform_later(photo.id)
      end
    end
  end
   