# app/jobs/cleanup_orphaned_s3_job.rb
#
# Finds S3 objects under the photos/ prefix with no corresponding Photo record
# and deletes them. Runs weekly to prevent S3 cost creep from failed uploads.
 
class CleanupOrphanedS3Job < ApplicationJob
    queue_as :low
   
    S3_PREFIX = 'photos/'.freeze
   
    def perform
      bucket     = S3Service.default_bucket
      s3_keys    = S3Service.list_keys(S3_PREFIX, bucket: bucket)
      db_keys    = Photo.pluck(:s3_key)
   
      # Also include thumbnail and medium variant keys from DB records
      variant_keys = db_keys.flat_map do |key|
        [
          Photo.build_thumbnail_key(key),
          Photo.build_medium_key(key)
        ]
      end
   
      known_keys  = (db_keys + variant_keys).to_set
      orphan_keys = s3_keys.reject { |k| known_keys.include?(k) }
   
      if orphan_keys.any?
        Rails.logger.info "[CleanupOrphanedS3Job] Deleting #{orphan_keys.size} orphaned S3 objects"
        S3Service.delete_many(orphan_keys, bucket: bucket)
      else
        Rails.logger.info "[CleanupOrphanedS3Job] No orphaned S3 objects found"
      end
    end
  end
   