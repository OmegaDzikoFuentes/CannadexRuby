# app/jobs/refresh_photo_urls_job.rb
#
# Refreshes S3 presigned URLs for all photos before they expire.
# Presigned URLs default to 1 hour TTL. This job runs every 6 hours
# but only updates photos whose URLs are close to expiry or already expired.
# In production, consider using CloudFront instead to avoid URL expiry entirely.
 
class RefreshPhotoUrlsJob < ApplicationJob
    queue_as :low
   
    BATCH_SIZE = 100
   
    def perform
      refreshed = 0
      failed    = 0
   
      # Only refresh photos that exist (complete/failed analyses included — URL still needed)
      Photo.in_batches(of: BATCH_SIZE) do |batch|
        batch.each do |photo|
          photo.refresh_urls!
          refreshed += 1
        rescue S3Service::Error, S3Service::NotFoundError => e
          Rails.logger.warn "[RefreshPhotoUrlsJob] Skipping photo #{photo.id}: #{e.message}"
          failed += 1
        end
      end
   
      Rails.logger.info "[RefreshPhotoUrlsJob] Refreshed #{refreshed} photos, #{failed} failed"
    end
  end