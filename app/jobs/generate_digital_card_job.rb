# app/jobs/generate_digital_card_job.rb
class GenerateDigitalCardJob < ApplicationJob
    queue_as :default
    retry_on StandardError, wait: 5.seconds, attempts: 3
  
    def perform(encounter_id)
      encounter = Encounter.find(encounter_id)
      
      # Skip if already generated and recent
      if encounter.card_generated? && encounter.card_image_url.present? && encounter.updated_at > 1.hour.ago
        Rails.logger.info "Card already generated for encounter #{encounter_id}, skipping"
        return
      end
  
      Rails.logger.info "Generating digital card for encounter #{encounter_id}"
      
      # Render HTML template to string with error handling
      html = render_card_template(encounter)
      
      # Generate image using Grover
      image_data = generate_image_from_html(html)
      
      # Upload to S3 with error handling
      image_url = upload_to_s3(image_data, encounter.id)
      
      # Update encounter record
      encounter.update!(
        card_image_url: image_url,
        card_generated: true
      )
      
      Rails.logger.info "Successfully generated card for encounter #{encounter_id}: #{image_url}"
      
      # Optionally trigger achievement check
      check_card_generation_achievements(encounter.user)
      
    rescue ActiveRecord::RecordNotFound => e
      Rails.logger.error "Encounter #{encounter_id} not found: #{e.message}"
      raise e
    rescue => e
      Rails.logger.error "Failed to generate card for encounter #{encounter_id}: #{e.message}"
      encounter&.update(card_generated: false) if encounter
      raise e
    end
  
    private
  
    def render_card_template(encounter)
      ApplicationController.render(
        template: 'encounters/digital_card',
        locals: { encounter: encounter },
        formats: [:html],
        layout: false
      )
    rescue => e
      Rails.logger.error "Failed to render template: #{e.message}"
      raise "Template rendering failed: #{e.message}"
    end
  
    def generate_image_from_html(html)
      # Grover options for high-quality image generation
      options = {
        format: 'PNG',
        width: 600,
        height: 800,
        quality: 100,
        device_scale_factor: 2, # For retina/high-DPI displays
        wait_until: 'networkidle0', # Wait for all network requests to complete
        timeout: 30000, # 30 second timeout
        launch_args: [
          '--no-sandbox',
          '--disable-setuid-sandbox',
          '--disable-dev-shm-usage'
        ]
      }
      
      grover = Grover.new(html, options)
      image_data = grover.to_png
      
      if image_data.nil? || image_data.empty?
        raise "Generated image data is empty"
      end
      
      image_data
    rescue => e
      Rails.logger.error "Grover image generation failed: #{e.message}"
      raise "Image generation failed: #{e.message}"
    end
  
    def upload_to_s3(image_data, encounter_id)
      # Ensure S3 is configured
      unless Rails.application.credentials.dig(:aws, :access_key_id)
        raise "AWS credentials not configured"
      end
      
      s3_client = Aws::S3::Client.new(
        region: Rails.application.credentials.dig(:aws, :region) || 'us-east-1',
        access_key_id: Rails.application.credentials.dig(:aws, :access_key_id),
        secret_access_key: Rails.application.credentials.dig(:aws, :secret_access_key)
      )
      
      bucket_name = Rails.application.credentials.dig(:aws, :s3_bucket) || ENV['S3_BUCKET_NAME']
      key = "cards/encounter-#{encounter_id}-#{Time.current.to_i}.png"
      
      # Upload with public read access
      s3_client.put_object(
        bucket: bucket_name,
        key: key,
        body: image_data,
        content_type: 'image/png',
        acl: 'public-read',
        cache_control: 'public, max-age=31536000', # Cache for 1 year
        metadata: {
          'encounter_id' => encounter_id.to_s,
          'generated_at' => Time.current.iso8601
        }
      )
      
      # Return the public URL
      "https://#{bucket_name}.s3.amazonaws.com/#{key}"
      
    rescue Aws::S3::Errors::ServiceError => e
      Rails.logger.error "S3 upload failed: #{e.message}"
      raise "S3 upload failed: #{e.message}"
    rescue => e
      Rails.logger.error "Unexpected error during S3 upload: #{e.message}"
      raise "Upload failed: #{e.message}"
    end
  
    def check_card_generation_achievements(user)
      # Trigger achievement checks in a separate job to avoid blocking
      CheckAchievementJob.perform_later(user.id, 'card_generated')
    rescue => e
      Rails.logger.warn "Achievement check failed: #{e.message}"
      # Don't re-raise since this is optional
    end
  end
  
  # Optional: Achievement checking job
  class CheckAchievementJob < ApplicationJob
    queue_as :low_priority
  
    def perform(user_id, achievement_type)
      user = User.find(user_id)
      
      case achievement_type
      when 'card_generated'
        check_first_card_achievement(user)
        check_card_milestone_achievements(user)
      end
    end
  
    private
  
    def check_first_card_achievement(user)
      return if user.achievements.where(achievement_type: 'first_card').exists?
      
      if user.encounters.where(card_generated: true).count == 1
        user.achievements.create!(
          achievement_type: 'first_card',
          title: 'First Digital Card',
          description: 'Generated your first CannaDex card!',
          progress: 1,
          goal: 1,
          xp_reward: 50,
          is_unlocked: true,
          unlocked_at: Time.current
        )
      end
    end
  
    def check_card_milestone_achievements(user)
      card_count = user.encounters.where(card_generated: true).count
      milestones = [10, 25, 50, 100]
      
      milestones.each do |milestone|
        next if card_count < milestone
        next if user.achievements.where(achievement_type: "cards_#{milestone}").exists?
        
        user.achievements.create!(
          achievement_type: "cards_#{milestone}",
          title: "Card Collector #{milestone}",
          description: "Generated #{milestone} digital cards!",
          progress: milestone,
          goal: milestone,
          xp_reward: milestone * 10,
          is_unlocked: true,
          unlocked_at: Time.current
        )
      end
    end
  end