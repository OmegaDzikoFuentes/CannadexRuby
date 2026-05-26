# app/models/photo.rb
class Photo < ApplicationRecord
    belongs_to :encounter
    belongs_to :user
    has_many   :strain_identifications, dependent: :destroy
    has_one    :latest_identification,
               -> { order(attempt_number: :desc) },
               class_name: 'StrainIdentification'
  
    # ---------------------------------------------------------------------------
    # Validations
    # ---------------------------------------------------------------------------
    validates :s3_key,     presence: true, uniqueness: true
    validates :s3_bucket,  presence: true
    validates :content_type, inclusion: {
      in: %w[image/jpeg image/png image/heic image/heif image/webp],
      message: "must be a supported image format"
    }, allow_nil: true
    validates :analysis_status, inclusion: {
      in: %w[pending processing complete failed skipped]
    }
    validates :analysis_attempts, numericality: { greater_than_or_equal_to: 0 }
  
    # ---------------------------------------------------------------------------
    # Scopes — query, sort, filter by photo properties
    # ---------------------------------------------------------------------------
  
    # -- Status --
    scope :pending_analysis,  -> { where(analysis_status: 'pending') }
    scope :processing,        -> { where(analysis_status: 'processing') }
    scope :analysis_complete, -> { where(analysis_status: 'complete') }
    scope :analysis_failed,   -> { where(analysis_status: 'failed') }
    scope :retryable,         -> { analysis_failed.where('analysis_attempts < ?', MAX_ANALYSIS_ATTEMPTS) }
  
    # -- Primary photo --
    scope :primary,      -> { where(is_primary: true) }
    scope :non_primary,  -> { where(is_primary: false) }
  
    # -- Sorting --
    scope :recent,       -> { order(created_at: :desc) }
    scope :oldest,       -> { order(created_at: :asc) }
    scope :by_taken_at,  -> { order(Arel.sql("taken_at DESC NULLS LAST")) }
  
    # -- Filter by EXIF / capture metadata --
    scope :taken_between, ->(from, to) { where(taken_at: from..to) }
    scope :taken_after,   ->(date)     { where('taken_at >= ?', date) }
    scope :taken_before,  ->(date)     { where('taken_at <= ?', date) }
  
    # -- Filter by AI visual features (jsonb) --
    # Example: Photo.with_trichome_density('high')
    scope :with_trichome_density, ->(density) {
      where("ai_analysis->>'trichome_density' = ?", density)
    }
    scope :with_bud_structure, ->(structure) {
      where("ai_analysis->>'bud_structure' = ?", structure)
    }
    scope :with_color, ->(color) {
      where("ai_analysis->'color_profile' ? :color", color: color)
    }
    scope :with_estimated_quality_above, ->(score) {
      where("(ai_analysis->>'estimated_quality')::float >= ?", score)
    }
  
    # -- Filter by content type --
    scope :jpegs, -> { where(content_type: 'image/jpeg') }
    scope :heic,  -> { where(content_type: %w[image/heic image/heif]) }
  
    # -- Filter by file size --
    scope :larger_than,  ->(bytes) { where('file_size_bytes > ?', bytes) }
    scope :smaller_than, ->(bytes) { where('file_size_bytes < ?', bytes) }
  
    # -- Filter by user --
    scope :for_user,      ->(user)     { where(user: user) }
    scope :for_encounter, ->(encounter) { where(encounter: encounter) }
  
    # ---------------------------------------------------------------------------
    # Constants
    # ---------------------------------------------------------------------------
    MAX_ANALYSIS_ATTEMPTS = 3
    THUMBNAIL_WIDTH  = 300
    MEDIUM_WIDTH     = 800
  
    # ---------------------------------------------------------------------------
    # Callbacks
    # ---------------------------------------------------------------------------
    after_create  :ensure_one_primary_per_encounter
    after_create  :enqueue_analysis
    after_destroy :delete_from_s3
  
    # ---------------------------------------------------------------------------
    # S3 methods
    # ---------------------------------------------------------------------------
  
    # Build the S3 object key for a new upload
    # Called before upload, not after — key is determined by the uploader
    def self.build_s3_key(user_id:, filename:)
      ext       = File.extname(filename).downcase
      basename  = SecureRandom.hex(16)
      "photos/user_#{user_id}/#{basename}#{ext}"
    end
  
    def self.build_thumbnail_key(original_key)
      dir  = File.dirname(original_key)
      base = File.basename(original_key, '.*')
      ext  = File.extname(original_key)
      "#{dir}/thumbs/#{base}_thumb#{ext}"
    end
  
    def self.build_medium_key(original_key)
      dir  = File.dirname(original_key)
      base = File.basename(original_key, '.*')
      ext  = File.extname(original_key)
      "#{dir}/medium/#{base}_medium#{ext}"
    end
  
    # Presigned URL for direct browser display (expires in 1 hour by default)
    def presigned_url(expires_in: 3600)
      S3Service.presigned_url(s3_key, bucket: s3_bucket, expires_in: expires_in)
    end
  
    def presigned_thumbnail_url(expires_in: 3600)
      return presigned_url(expires_in: expires_in) unless thumbnail_url.present?
      S3Service.presigned_url(
        self.class.build_thumbnail_key(s3_key),
        bucket: s3_bucket,
        expires_in: expires_in
      )
    end
  
    # Refresh cached URLs and persist (call from a background job periodically)
    def refresh_urls!
      update!(
        url:           S3Service.presigned_url(s3_key, bucket: s3_bucket),
        thumbnail_url: S3Service.presigned_url(self.class.build_thumbnail_key(s3_key), bucket: s3_bucket),
        medium_url:    S3Service.presigned_url(self.class.build_medium_key(s3_key), bucket: s3_bucket)
      )
    end
  
    # ---------------------------------------------------------------------------
    # EXIF helpers
    # ---------------------------------------------------------------------------
  
    def exif_device
      exif_data['make'].to_s + ' ' + exif_data['model'].to_s
    end
  
    def exif_gps
      return nil unless exif_data['gps_latitude'] && exif_data['gps_longitude']
      { lat: exif_data['gps_latitude'], lng: exif_data['gps_longitude'] }
    end
  
    def exif_captured_at
      return nil unless exif_data['date_time_original']
      Time.parse(exif_data['date_time_original']) rescue nil
    end
  
    # ---------------------------------------------------------------------------
    # AI analysis helpers
    # ---------------------------------------------------------------------------
  
    def color_profile
      ai_analysis['color_profile'] || []
    end
  
    def trichome_density
      ai_analysis['trichome_density']
    end
  
    def bud_structure
      ai_analysis['bud_structure']
    end
  
    def estimated_quality
      ai_analysis['estimated_quality']&.to_f
    end
  
    def analysis_pending?
      analysis_status == 'pending'
    end
  
    def analysis_complete?
      analysis_status == 'complete'
    end
  
    def analysis_failed?
      analysis_status == 'failed'
    end
  
    def retryable?
      analysis_failed? && analysis_attempts < MAX_ANALYSIS_ATTEMPTS
    end
  
    def mark_analysis_processing!
      update!(analysis_status: 'processing', analysis_attempts: analysis_attempts + 1)
    end
  
    def complete_analysis!(ai_result_hash)
      update!(
        analysis_status: 'complete',
        ai_analysis:     ai_result_hash,
        analyzed_at:     Time.current
      )
    end
  
    def fail_analysis!
      update!(analysis_status: 'failed')
    end
  
    # ---------------------------------------------------------------------------
    # Primary photo management
    # ---------------------------------------------------------------------------
  
    def make_primary!
      transaction do
        encounter.photos.where.not(id: id).update_all(is_primary: false)
        update!(is_primary: true)
      end
    end
  
    # ---------------------------------------------------------------------------
    # Dimensions helper
    # ---------------------------------------------------------------------------
  
    def dimensions
      return nil unless width_px && height_px
      "#{width_px}x#{height_px}"
    end
  
    def portrait?
      return nil unless width_px && height_px
      height_px > width_px
    end
  
    def landscape?
      return nil unless width_px && height_px
      width_px > height_px
    end
  
    def file_size_mb
      return nil unless file_size_bytes
      (file_size_bytes.to_f / 1.megabyte).round(2)
    end
  
    private
  
    def ensure_one_primary_per_encounter
      # If this is the first photo for an encounter, make it primary automatically
      if encounter.photos.count == 1
        update_column(:is_primary, true)
      end
    end
  
    def enqueue_analysis
      AnalyzePhotoJob.perform_later(id)
    end
  
    def delete_from_s3
      S3Service.delete(s3_key, bucket: s3_bucket)
      S3Service.delete(self.class.build_thumbnail_key(s3_key), bucket: s3_bucket)
      S3Service.delete(self.class.build_medium_key(s3_key), bucket: s3_bucket)
    rescue S3Service::Error => e
      Rails.logger.error "Failed to delete S3 objects for photo #{id}: #{e.message}"
      # Don't re-raise — deletion failure shouldn't block DB record removal
    end
  end