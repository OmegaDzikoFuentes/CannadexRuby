# config/initializers/aws.rb
#
# Configures the AWS SDK globally and validates credentials on boot.
# Also sets the OpenAI client defaults.

require 'aws-sdk-s3'

# ── AWS SDK global configuration ──────────────────────────────────────────────

Aws.config.update(
  region:            Rails.application.credentials.dig(:aws, :region) ||
                     ENV.fetch('AWS_REGION', 'us-east-1'),
  access_key_id:     Rails.application.credentials.dig(:aws, :access_key_id) ||
                     ENV['AWS_ACCESS_KEY_ID'],
  secret_access_key: Rails.application.credentials.dig(:aws, :secret_access_key) ||
                     ENV['AWS_SECRET_ACCESS_KEY'],

  # Retry configuration for the SDK globally
  retry_mode:  'adaptive',   # adaptive = respects Retry-After headers
  max_attempts: 3,

  # Log S3 calls in development
  logger: Rails.env.development? ? Rails.logger : nil,
  log_level: :debug
)

# ── Validate credentials on boot (non-test environments) ─────────────────────

unless Rails.env.test?
  Rails.application.config.after_initialize do
    required_aws = %i[access_key_id secret_access_key region s3_bucket]
    missing = required_aws.select do |key|
      Rails.application.credentials.dig(:aws, key).blank? && ENV["AWS_#{key.to_s.upcase}"].blank?
    end

    if missing.any?
      message = "[AWS] Missing required configuration: #{missing.join(', ')}. " \
                "Set via `rails credentials:edit` or environment variables."
      if Rails.env.production?
        raise RuntimeError, message
      else
        Rails.logger.warn message
      end
    else
      Rails.logger.info "[AWS] S3 configured — bucket: #{
        Rails.application.credentials.dig(:aws, :s3_bucket) || ENV['AWS_S3_BUCKET']
      }, region: #{
        Rails.application.credentials.dig(:aws, :region) || ENV.fetch('AWS_REGION', 'us-east-1')
      }"
    end
  end
end

# ── S3 bucket CORS configuration helper ──────────────────────────────────────
# Run this once in a Rails console or a rake task to set CORS on your bucket.
# Required for direct browser → S3 uploads (presigned PUT URLs).
#
# Usage: AwsSetup.configure_cors!
#
module AwsSetup
  def self.configure_cors!(bucket: nil)
    bucket ||= Rails.application.credentials.dig(:aws, :s3_bucket)
    client = Aws::S3::Client.new

    allowed_origins = case Rails.env
                      when 'production'  then ['https://cannadex.com', 'https://www.cannadex.com']
                      when 'staging'     then ['https://staging.cannadex.com']
                      else ['http://localhost:3000', 'http://localhost:3001', 'exp://localhost:8081']
                      end

    client.put_bucket_cors(
      bucket: bucket,
      cors_configuration: {
        cors_rules: [
          {
            allowed_headers: ['*'],
            allowed_methods: ['GET', 'PUT', 'POST', 'DELETE', 'HEAD'],
            allowed_origins: allowed_origins,
            expose_headers:  ['ETag', 'x-amz-request-id'],
            max_age_seconds: 3600
          }
        ]
      }
    )

    Rails.logger.info "[AwsSetup] CORS configured for bucket #{bucket}"
  end

  # Sets a lifecycle rule to clean up incomplete multipart uploads after 7 days
  def self.configure_lifecycle!(bucket: nil)
    bucket ||= Rails.application.credentials.dig(:aws, :s3_bucket)
    client = Aws::S3::Client.new

    client.put_bucket_lifecycle_configuration(
      bucket: bucket,
      lifecycle_configuration: {
        rules: [
          {
            id:     'abort-incomplete-multipart',
            status: 'Enabled',
            abort_incomplete_multipart_upload: { days_after_initiation: 7 },
            filter: { prefix: 'photos/' }
          },
          {
            id:     'expire-temp-uploads',
            status: 'Enabled',
            expiration: { days: 1 },
            filter: { prefix: 'tmp/' }
          }
        ]
      }
    )

    Rails.logger.info "[AwsSetup] Lifecycle rules configured for bucket #{bucket}"
  end
end