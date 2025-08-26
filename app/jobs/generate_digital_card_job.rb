# app/jobs/generate_digital_card_job.rb
class GenerateDigitalCardJob < ApplicationJob
    queue_as :default
  
    def perform(encounter_id)
      encounter = Encounter.find(encounter_id)
  
      # Render HTML template to string
      html = ApplicationController.render(
        partial: 'encounters/digital_card',
        locals: { encounter: encounter },
        formats: [:html]
      )
  
      # Use Grover to convert HTML to PNG image
      grover = Grover.new(html, format: 'PNG', width: 600, height: 800)  # Adjust size as needed
      image_data = grover.to_png
  
      # Upload to S3 (assuming aws-sdk-s3 is configured)
      s3 = Aws::S3::Resource.new
      obj = s3.bucket('your-bucket-name').object("cards/#{encounter.id}.png")  # Replace 'your-bucket-name'
      obj.put(body: image_data, acl: 'public-read')
  
      # Update encounter with public URL
      encounter.update!(
        card_image_url: obj.public_url,
        card_generated: true
      )
    end
  end