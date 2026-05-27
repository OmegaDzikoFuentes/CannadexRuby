# app/services/s3_service.rb
#
# Wraps AWS S3 operations for photo storage.
# All public methods raise S3Service::Error on failure.
#
# Usage:
#   result  = S3Service.upload(file, key: "photos/user_1/abc.jpg")
#   url     = S3Service.presigned_url("photos/user_1/abc.jpg")
#   S3Service.delete("photos/user_1/abc.jpg")
#   S3Service.copy("photos/old.jpg", "photos/new.jpg")
#   exists  = S3Service.exists?("photos/user_1/abc.jpg")
#   meta    = S3Service.metadata("photos/user_1/abc.jpg")
#   S3Service.download("photos/user_1/abc.jpg") { |chunk| ... }

class S3Service
    class Error           < StandardError; end
    class NotFoundError   < Error; end
    class UploadError     < Error; end
    class DeleteError     < Error; end
    class PresignError    < Error; end
  
    # Multipart threshold — files above this use multipart upload (AWS recommends 100MB+)
    MULTIPART_THRESHOLD = 15.megabytes
    # Default presigned URL TTL
    DEFAULT_PRESIGN_TTL = 3600       # 1 hour
    # Maximum retries for transient failures
    MAX_RETRIES = 3
    # Supported image MIME types
    ALLOWED_CONTENT_TYPES = %w[
      image/jpeg
      image/png
      image/webp
      image/heic
      image/heif
    ].freeze
  
    # -------------------------------------------------------------------------
    # Class-level API (delegates to a singleton instance per bucket)
    # -------------------------------------------------------------------------
  
    def self.upload(file_or_path, key:, bucket: default_bucket, content_type: nil, metadata: {})
      instance(bucket).upload(file_or_path, key: key, content_type: content_type, metadata: metadata)
    end
  
    def self.presigned_url(key, bucket: default_bucket, expires_in: DEFAULT_PRESIGN_TTL, method: :get)
      instance(bucket).presigned_url(key, expires_in: expires_in, method: method)
    end
  
    def self.presigned_upload_url(key, bucket: default_bucket, content_type:, expires_in: 900)
      instance(bucket).presigned_upload_url(key, content_type: content_type, expires_in: expires_in)
    end
  
    def self.delete(key, bucket: default_bucket)
      instance(bucket).delete(key)
    end
  
    def self.delete_many(keys, bucket: default_bucket)
      instance(bucket).delete_many(keys)
    end
  
    def self.copy(source_key, dest_key, source_bucket: default_bucket, dest_bucket: default_bucket)
      instance(source_bucket).copy(source_key, dest_key, dest_bucket: dest_bucket)
    end
  
    def self.exists?(key, bucket: default_bucket)
      instance(bucket).exists?(key)
    end
  
    def self.metadata(key, bucket: default_bucket)
      instance(bucket).metadata(key)
    end
  
    def self.download(key, bucket: default_bucket, &block)
      instance(bucket).download(key, &block)
    end
  
    def self.download_to_tempfile(key, bucket: default_bucket)
      instance(bucket).download_to_tempfile(key)
    end
  
    def self.list_keys(prefix, bucket: default_bucket)
      instance(bucket).list_keys(prefix)
    end
  
    def self.default_bucket
      Rails.application.credentials.dig(:aws, :s3_bucket) ||
        ENV.fetch('AWS_S3_BUCKET') { raise Error, "AWS S3 bucket not configured" }
    end
  
    # -------------------------------------------------------------------------
    # Instance (per bucket)
    # -------------------------------------------------------------------------
  
    def initialize(bucket)
      @bucket = bucket
      @client = build_client
      @resource = Aws::S3::Resource.new(client: @client)
      @signer = Aws::S3::Presigner.new(client: @client)
    end
  
    # -- Upload ---------------------------------------------------------------
  
    def upload(file_or_path, key:, content_type: nil, metadata: {})
      path          = resolve_path(file_or_path)
      content_type  = content_type || detect_content_type(path)
      file_size     = File.size(path)
  
      validate_content_type!(content_type)
  
      with_retries("upload #{key}") do
        if file_size > MULTIPART_THRESHOLD
          multipart_upload(path, key: key, content_type: content_type, metadata: metadata)
        else
          simple_upload(path, key: key, content_type: content_type, metadata: metadata)
        end
      end
  
      Rails.logger.info "[S3Service] Uploaded #{key} (#{content_type}, #{file_size} bytes)"
  
      {
        key:          key,
        bucket:       @bucket,
        content_type: content_type,
        file_size:    file_size,
        url:          public_url(key)
      }
    rescue Aws::S3::Errors::ServiceError => e
      raise UploadError, "Failed to upload #{key}: #{e.message}"
    end
  
    # -- Presigned URLs -------------------------------------------------------
  
    def presigned_url(key, expires_in: DEFAULT_PRESIGN_TTL, method: :get)
      @signer.presigned_url(
        :"#{method}_object",
        bucket:     @bucket,
        key:        key,
        expires_in: expires_in
      )
    rescue Aws::Errors::NoSuchKey, Aws::S3::Errors::ServiceError => e
      raise PresignError, "Failed to presign #{key}: #{e.message}"
    end
  
    # Presigned URL for direct browser → S3 upload (avoids routing through your server)
    def presigned_upload_url(key, content_type:, expires_in: 900)
      @signer.presigned_url(
        :put_object,
        bucket:      @bucket,
        key:         key,
        expires_in:  expires_in,
        content_type: content_type
      )
    rescue Aws::S3::Errors::ServiceError => e
      raise PresignError, "Failed to presign upload for #{key}: #{e.message}"
    end
  
    # -- Delete ---------------------------------------------------------------
  
    def delete(key)
      with_retries("delete #{key}") do
        @client.delete_object(bucket: @bucket, key: key)
      end
      Rails.logger.info "[S3Service] Deleted #{key}"
      true
    rescue Aws::S3::Errors::ServiceError => e
      raise DeleteError, "Failed to delete #{key}: #{e.message}"
    end
  
    # Batch delete (up to 1000 keys per AWS call)
    def delete_many(keys)
      return if keys.empty?
      keys.each_slice(1000) do |batch|
        objects = batch.map { |k| { key: k } }
        with_retries("batch delete #{batch.size} keys") do
          @client.delete_objects(
            bucket: @bucket,
            delete: { objects: objects, quiet: true }
          )
        end
      end
      Rails.logger.info "[S3Service] Batch deleted #{keys.size} keys"
      true
    rescue Aws::S3::Errors::ServiceError => e
      raise DeleteError, "Failed to batch delete: #{e.message}"
    end
  
    # -- Copy -----------------------------------------------------------------
  
    def copy(source_key, dest_key, dest_bucket: @bucket)
      with_retries("copy #{source_key} → #{dest_key}") do
        @client.copy_object(
          bucket:      dest_bucket,
          copy_source: "#{@bucket}/#{source_key}",
          key:         dest_key
        )
      end
      Rails.logger.info "[S3Service] Copied #{source_key} → #{dest_key}"
      true
    rescue Aws::S3::Errors::ServiceError => e
      raise Error, "Failed to copy #{source_key}: #{e.message}"
    end
  
    # -- Existence / Metadata -------------------------------------------------
  
    def exists?(key)
      @client.head_object(bucket: @bucket, key: key)
      true
    rescue Aws::S3::Errors::NotFound, Aws::S3::Errors::NoSuchKey
      false
    end
  
    def metadata(key)
      resp = @client.head_object(bucket: @bucket, key: key)
      {
        content_type:   resp.content_type,
        content_length: resp.content_length,
        last_modified:  resp.last_modified,
        etag:           resp.etag&.delete('"'),
        metadata:       resp.metadata
      }
    rescue Aws::S3::Errors::NotFound, Aws::S3::Errors::NoSuchKey
      raise NotFoundError, "Object not found: #{key}"
    rescue Aws::S3::Errors::ServiceError => e
      raise Error, "Failed to get metadata for #{key}: #{e.message}"
    end
  
    # -- Download -------------------------------------------------------------
  
    # Streaming download — yields chunks (memory efficient for large files)
    def download(key, &block)
      @client.get_object(bucket: @bucket, key: key) do |chunk|
        block.call(chunk)
      end
    rescue Aws::S3::Errors::NoSuchKey
      raise NotFoundError, "Object not found: #{key}"
    rescue Aws::S3::Errors::ServiceError => e
      raise Error, "Failed to download #{key}: #{e.message}"
    end
  
    # Download to a Tempfile (returned — caller is responsible for closing/unlinking)
    def download_to_tempfile(key)
      ext      = File.extname(key)
      tempfile = Tempfile.new(['s3_download', ext], binmode: true)
  
      download(key) { |chunk| tempfile.write(chunk) }
      tempfile.rewind
      tempfile
    rescue => e
      tempfile&.close
      tempfile&.unlink
      raise
    end
  
    # -- List -----------------------------------------------------------------
  
    def list_keys(prefix)
      keys = []
      @client.list_objects_v2(bucket: @bucket, prefix: prefix).each_page do |page|
        keys.concat(page.contents.map(&:key))
      end
      keys
    rescue Aws::S3::Errors::ServiceError => e
      raise Error, "Failed to list keys with prefix #{prefix}: #{e.message}"
    end
  
    private
  
    # -------------------------------------------------------------------------
    # Internal helpers
    # -------------------------------------------------------------------------
  
    def self.instance(bucket)
      @instances ||= {}
      @instances[bucket] ||= new(bucket)
    end
  
    def build_client
      Aws::S3::Client.new(
        region:            aws_region,
        access_key_id:     aws_access_key_id,
        secret_access_key: aws_secret_access_key,
        # Retry configuration
        retry_limit:   MAX_RETRIES,
        retry_backoff: ->(context) { sleep(2 ** context.retries * 0.3) }
      )
    end
  
    def simple_upload(path, key:, content_type:, metadata:)
      File.open(path, 'rb') do |file|
        @client.put_object(
          bucket:       @bucket,
          key:          key,
          body:         file,
          content_type: content_type,
          metadata:     metadata.transform_keys(&:to_s),
          server_side_encryption: 'AES256'
        )
      end
    end
  
    def multipart_upload(path, key:, content_type:, metadata:)
      uploader = Aws::S3::MultipartUpload
      @resource.bucket(@bucket).object(key).upload_file(
        path,
        content_type:           content_type,
        metadata:               metadata.transform_keys(&:to_s),
        server_side_encryption: 'AES256',
        multipart_threshold:    MULTIPART_THRESHOLD
      )
    end
  
    def public_url(key)
      "https://#{@bucket}.s3.#{aws_region}.amazonaws.com/#{key}"
    end
  
    def resolve_path(file_or_path)
      case file_or_path
      when String, Pathname then file_or_path.to_s
      when Tempfile         then file_or_path.path
      when File             then file_or_path.path
      else
        raise ArgumentError, "Expected a file path, File, or Tempfile, got #{file_or_path.class}"
      end
    end
  
    def detect_content_type(path)
      Marcel::MimeType.for(Pathname.new(path)) || 'application/octet-stream'
    end
  
    def validate_content_type!(content_type)
      return if ALLOWED_CONTENT_TYPES.include?(content_type)
      raise UploadError, "Unsupported content type: #{content_type}. Allowed: #{ALLOWED_CONTENT_TYPES.join(', ')}"
    end
  
    def with_retries(operation, &block)
      attempts = 0
      begin
        block.call
      rescue Aws::S3::Errors::ServiceError, Aws::Errors::NetworkingError => e
        attempts += 1
        if attempts < MAX_RETRIES
          wait = 2 ** attempts * 0.5
          Rails.logger.warn "[S3Service] Retrying #{operation} (attempt #{attempts}): #{e.message}"
          sleep(wait)
          retry
        else
          raise
        end
      end
    end
  
    def aws_region
      Rails.application.credentials.dig(:aws, :region) ||
        ENV.fetch('AWS_REGION', 'us-east-1')
    end
  
    def aws_access_key_id
      Rails.application.credentials.dig(:aws, :access_key_id) ||
        ENV.fetch('AWS_ACCESS_KEY_ID') { raise Error, "AWS access key not configured" }
    end
  
    def aws_secret_access_key
      Rails.application.credentials.dig(:aws, :secret_access_key) ||
        ENV.fetch('AWS_SECRET_ACCESS_KEY') { raise Error, "AWS secret key not configured" }
    end
  end