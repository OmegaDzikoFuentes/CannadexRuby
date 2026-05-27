# app/services/photo_upload_service.rb
#
# Orchestrates the full photo intake pipeline:
#   1. Process image (EXIF, resize, thumbnails)
#   2. Upload original + variants to S3
#   3. Create Photo record with all metadata
#   4. Kick off AI analysis job
#
# Usage:
#   result = PhotoUploadService.call(
#     encounter: encounter,
#     user: user,
#     file: params[:photo],          # ActionDispatch::Http::UploadedFile or Tempfile
#     original_filename: "bud.jpg",
#     make_primary: true             # optional, defaults to true if first photo
#   )
#
#   if result.success?
#     result.photo   # Photo record
#   else
#     result.error   # error message string
#   end

class PhotoUploadService
    Result = Struct.new(:photo, :error, keyword_init: true) do
      def success? = error.nil?
      def failure? = !success?
    end
  
    def self.call(...)
      new(...).call
    end
  
    def initialize(encounter:, user:, file:, original_filename: nil, make_primary: nil)
      @encounter         = encounter
      @user              = user
      @file              = file
      @original_filename = original_filename || extract_filename(file)
      @make_primary      = make_primary
    end
  
    def call
      # Step 1 — Process image locally
      processed = ImageProcessingService.process(@file, original_filename: @original_filename)
  
      # Step 2 — Build S3 keys
      s3_key           = Photo.build_s3_key(user_id: @user.id, filename: @original_filename)
      s3_thumbnail_key = Photo.build_thumbnail_key(s3_key)
      s3_medium_key    = Photo.build_medium_key(s3_key)
      bucket           = S3Service.default_bucket
  
      # Step 3 — Upload all variants to S3 in parallel
      upload_results = upload_variants(
        processed:       processed,
        s3_key:          s3_key,
        s3_thumbnail_key: s3_thumbnail_key,
        s3_medium_key:   s3_medium_key,
        bucket:          bucket
      )
  
      # Step 4 — Determine if this should be the primary photo
      should_be_primary = @make_primary.nil? ? @encounter.photos.none? : @make_primary
  
      # Step 5 — Create the Photo record
      photo = Photo.create!(
        encounter:         @encounter,
        user:              @user,
        s3_key:            s3_key,
        s3_bucket:         bucket,
        url:               upload_results[:original_url],
        thumbnail_url:     upload_results[:thumbnail_url],
        medium_url:        upload_results[:medium_url],
        is_primary:        should_be_primary,
        content_type:      processed.content_type,
        file_size_bytes:   processed.file_size,
        width_px:          processed.width,
        height_px:         processed.height,
        original_filename: @original_filename,
        exif_data:         processed.exif_data,
        taken_at:          parse_taken_at(processed.exif_data),
        analysis_status:   'pending'
      )
  
      # Step 6 — If this should be primary, ensure no other photo on the
      # encounter is also primary (handles race conditions)
      if should_be_primary
        Photo.where(encounter: @encounter)
             .where.not(id: photo.id)
             .update_all(is_primary: false)
      end
  
      Result.new(photo: photo)
  
    rescue ImageProcessingService::UnsupportedFormatError => e
      Result.new(error: "Unsupported image format: #{e.message}")
    rescue ImageProcessingService::ProcessingError => e
      Result.new(error: "Could not process image: #{e.message}")
    rescue S3Service::UploadError => e
      Result.new(error: "Upload failed: #{e.message}")
    rescue ActiveRecord::RecordInvalid => e
      Result.new(error: "Could not save photo: #{e.message}")
    rescue => e
      Rails.logger.error "[PhotoUploadService] Unexpected error: #{e.class} #{e.message}\n#{e.backtrace.first(5).join("\n")}"
      Result.new(error: "An unexpected error occurred")
    ensure
      # Always clean up temp files regardless of success or failure
      ImageProcessingService.cleanup(processed) if processed
    end
  
    private
  
    def upload_variants(processed:, s3_key:, s3_thumbnail_key:, s3_medium_key:, bucket:)
      # Upload original, thumbnail, and medium concurrently using threads
      results = {}
      errors  = []
  
      threads = [
        Thread.new {
          begin
            S3Service.upload(processed.original_path, key: s3_key, bucket: bucket,
                             content_type: processed.content_type,
                             metadata: { 'uploaded-by' => 'cannadex', 'variant' => 'original' })
            results[:original_url] = S3Service.presigned_url(s3_key, bucket: bucket)
          rescue => e
            errors << "Original: #{e.message}"
          end
        },
        Thread.new {
          begin
            S3Service.upload(processed.thumbnail_path, key: s3_thumbnail_key, bucket: bucket,
                             content_type: 'image/jpeg',
                             metadata: { 'variant' => 'thumbnail' })
            results[:thumbnail_url] = S3Service.presigned_url(s3_thumbnail_key, bucket: bucket)
          rescue => e
            errors << "Thumbnail: #{e.message}"
          end
        },
        Thread.new {
          begin
            S3Service.upload(processed.medium_path, key: s3_medium_key, bucket: bucket,
                             content_type: 'image/jpeg',
                             metadata: { 'variant' => 'medium' })
            results[:medium_url] = S3Service.presigned_url(s3_medium_key, bucket: bucket)
          rescue => e
            errors << "Medium: #{e.message}"
          end
        }
      ]
  
      threads.each(&:join)
      raise S3Service::UploadError, errors.join('; ') if errors.any?
  
      results
    end
  
    def extract_filename(file)
      case file
      when ActionDispatch::Http::UploadedFile then file.original_filename
      when Tempfile                            then File.basename(file.path)
      when String, Pathname                   then File.basename(file.to_s)
      else "upload_#{SecureRandom.hex(4)}.jpg"
      end
    end
  
    def parse_taken_at(exif_data)
      return nil unless exif_data[:date_time_original]
      Time.parse(exif_data[:date_time_original]) rescue nil
    end
  end 