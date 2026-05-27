# app/services/ai_identification_service.rb
#
# Sends a bud photo to GPT-4o Vision and returns a structured identification result.
# Designed to be model-agnostic — swap the provider method to use Rekognition, etc.
#
# Usage (called from AnalyzePhotoJob):
#   result = AiIdentificationService.call(photo)
#   result.success?         # => true
#   result.candidates       # => [{ strain_name: "Blue Dream", confidence: 0.91, strain_id: 42 }, ...]
#   result.visual_features  # => { color_profile: [...], trichome_density: "high", ... }
#   result.model_response   # => raw response hash for storage
#   result.model_name       # => "gpt-4o"
#   result.processing_ms    # => 1840

require 'openai'
require 'base64'

class AiIdentificationService
  class Error              < StandardError; end
  class ModelError         < Error; end
  class ParseError         < Error; end
  class RateLimitError     < Error; end
  class ImageFetchError    < Error; end

  MODEL_NAME    = 'gpt-4o'.freeze
  MODEL_VERSION = '2024-11-20'.freeze
  MAX_TOKENS    = 1000
  TEMPERATURE   = 0.1   # Low — we want deterministic structured output
  MAX_CANDIDATES = 5

  Result = Struct.new(
    :candidates,
    :visual_features,
    :model_response,
    :model_name,
    :model_version,
    :processing_ms,
    :error,
    keyword_init: true
  ) do
    def success? = error.nil?
    def failure? = !success?
    def top_candidate = candidates&.first
    def top_confidence = top_candidate&.dig(:confidence)
  end

  def self.call(photo)
    new(photo).call
  end

  def initialize(photo)
    @photo  = photo
    @client = build_client
  end

  def call
    started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    # Fetch image from S3 as base64
    image_data = fetch_image_base64

    # Build and send prompt
    raw_response = send_to_model(image_data)

    processing_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000).round

    # Parse structured response
    parsed = parse_response(raw_response)

    # Resolve strain IDs from the database
    candidates = resolve_strain_ids(parsed[:candidates])

    Result.new(
      candidates:      candidates,
      visual_features: parsed[:visual_features],
      model_response:  raw_response,
      model_name:      MODEL_NAME,
      model_version:   MODEL_VERSION,
      processing_ms:   processing_ms
    )

  rescue RateLimitError => e
    Rails.logger.warn "[AiIdentificationService] Rate limited: #{e.message}"
    Result.new(error: "rate_limited", model_name: MODEL_NAME, model_version: MODEL_VERSION)
  rescue ImageFetchError => e
    Rails.logger.error "[AiIdentificationService] Could not fetch image for photo #{@photo.id}: #{e.message}"
    Result.new(error: "image_fetch_failed", model_name: MODEL_NAME, model_version: MODEL_VERSION)
  rescue ParseError => e
    Rails.logger.error "[AiIdentificationService] Parse failed for photo #{@photo.id}: #{e.message}"
    Result.new(error: "parse_failed", model_name: MODEL_NAME, model_version: MODEL_VERSION)
  rescue ModelError => e
    Rails.logger.error "[AiIdentificationService] Model error for photo #{@photo.id}: #{e.message}"
    Result.new(error: "model_error", model_name: MODEL_NAME, model_version: MODEL_VERSION)
  end

  private

  # -------------------------------------------------------------------------
  # Image fetching
  # -------------------------------------------------------------------------

  def fetch_image_base64
    tempfile = S3Service.download_to_tempfile(@photo.s3_key, bucket: @photo.s3_bucket)
    Base64.strict_encode64(tempfile.read)
  rescue S3Service::NotFoundError => e
    raise ImageFetchError, "S3 object not found: #{e.message}"
  rescue S3Service::Error => e
    raise ImageFetchError, "S3 download failed: #{e.message}"
  ensure
    tempfile&.close
    tempfile&.unlink
  end

  # -------------------------------------------------------------------------
  # Model interaction
  # -------------------------------------------------------------------------

  def send_to_model(image_base64)
    response = @client.chat(
      parameters: {
        model:       MODEL_NAME,
        temperature: TEMPERATURE,
        max_tokens:  MAX_TOKENS,
        messages: [
          { role: 'system', content: system_prompt },
          {
            role: 'user',
            content: [
              {
                type: 'image_url',
                image_url: {
                  url:    "data:#{@photo.content_type || 'image/jpeg'};base64,#{image_base64}",
                  detail: 'high'   # high detail for trichome/texture analysis
                }
              },
              {
                type: 'text',
                text: user_prompt
              }
            ]
          }
        ]
      }
    )

    handle_api_errors(response)
    response
  rescue Faraday::TooManyRequestsError, OpenAI::Error => e
    raise RateLimitError, e.message if e.message.include?('rate_limit')
    raise ModelError, e.message
  end

  def handle_api_errors(response)
    if response.dig('error')
      code = response.dig('error', 'code')
      msg  = response.dig('error', 'message')
      raise RateLimitError, msg if code == 'rate_limit_exceeded'
      raise ModelError, "API error #{code}: #{msg}"
    end
  end

  # -------------------------------------------------------------------------
  # Prompt construction
  # -------------------------------------------------------------------------

  def system_prompt
    known_strains = Strain.verified.limit(500).pluck(:id, :name)
                         .map { |id, name| "#{id}:#{name}" }.join(', ')

    <<~PROMPT.strip
      You are an expert cannabis botanist and strain identifier with deep knowledge of visual
      cannabis characteristics. Your task is to analyze bud photos and identify strains.

      You will respond ONLY with a valid JSON object — no markdown, no explanation, no preamble.

      The known strain catalog (id:name pairs):
      #{known_strains}

      Your response must match this exact schema:
      {
        "candidates": [
          {
            "strain_name": "string — name of the strain",
            "strain_id": number_or_null — id from catalog if matched, null if not in catalog,
            "confidence": float — 0.0 to 1.0,
            "reasoning": "string — brief visual reasoning for this match"
          }
        ],
        "visual_features": {
          "color_profile": ["string array — e.g. deep green, orange hairs, purple tinge"],
          "trichome_density": "none | sparse | moderate | high | very_high",
          "bud_structure": "airy | moderate | dense | very_dense",
          "moisture_level": "too_dry | well_cured | slightly_moist | wet",
          "trim_quality": "machine_trimmed | hand_trimmed_rough | hand_trimmed_clean",
          "estimated_quality": float — 1.0 to 10.0 visual quality score,
          "leaf_to_bud_ratio": "leafy | balanced | tight",
          "visible_mold": boolean,
          "visible_seeds": boolean,
          "approximate_size": "small | medium | large | very_large"
        },
        "not_cannabis": boolean — true if the image does not appear to contain cannabis,
        "image_quality": "too_dark | blurry | too_bright | good | excellent"
      }

      Return between 1 and #{MAX_CANDIDATES} candidates, sorted by confidence descending.
      If you cannot identify any strain, return an empty candidates array.
      If the image is not cannabis, set not_cannabis: true and return empty candidates.
    PROMPT
  end

  def user_prompt
    "Please analyze this cannabis bud photo and identify the strain. " \
    "Examine trichome density, color profile, bud structure, and any other visual markers carefully."
  end

  # -------------------------------------------------------------------------
  # Response parsing
  # -------------------------------------------------------------------------

  def parse_response(raw_response)
    content = raw_response.dig('choices', 0, 'message', 'content')
    raise ParseError, "Empty model response" if content.blank?

    # Strip any accidental markdown fences
    json_str = content.gsub(/```json|```/, '').strip

    parsed = JSON.parse(json_str, symbolize_names: true)

    validate_parsed!(parsed)

    {
      candidates:      normalize_candidates(parsed[:candidates] || []),
      visual_features: normalize_visual_features(parsed[:visual_features] || {})
    }
  rescue JSON::ParserError => e
    raise ParseError, "Invalid JSON from model: #{e.message}. Content was: #{content&.first(200)}"
  end

  def validate_parsed!(parsed)
    raise ParseError, "Response missing 'candidates' key" unless parsed.key?(:candidates)
    raise ParseError, "Response missing 'visual_features' key" unless parsed.key?(:visual_features)
    raise ParseError, "'candidates' must be an array" unless parsed[:candidates].is_a?(Array)
  end

  def normalize_candidates(candidates)
    candidates.first(MAX_CANDIDATES).map do |c|
      {
        strain_name: c[:strain_name].to_s.strip,
        strain_id:   c[:strain_id]&.to_i,
        confidence:  c[:confidence].to_f.clamp(0.0, 1.0),
        reasoning:   c[:reasoning].to_s.truncate(300)
      }
    end.sort_by { |c| -c[:confidence] }
  end

  def normalize_visual_features(vf)
    {
      color_profile:      Array(vf[:color_profile]).map(&:to_s),
      trichome_density:   vf[:trichome_density].to_s,
      bud_structure:      vf[:bud_structure].to_s,
      moisture_level:     vf[:moisture_level].to_s,
      trim_quality:       vf[:trim_quality].to_s,
      estimated_quality:  vf[:estimated_quality]&.to_f&.clamp(1.0, 10.0),
      leaf_to_bud_ratio:  vf[:leaf_to_bud_ratio].to_s,
      visible_mold:       vf[:visible_mold] == true,
      visible_seeds:      vf[:visible_seeds] == true,
      approximate_size:   vf[:approximate_size].to_s,
      image_quality:      vf[:image_quality].to_s
    }.compact
  end

  # -------------------------------------------------------------------------
  # Strain ID resolution
  # -------------------------------------------------------------------------

  # Match model-returned strain names/ids against the actual database,
  # handling cases where the model hallucinates a name or ID mismatch.
  def resolve_strain_ids(candidates)
    return [] if candidates.empty?

    # Gather all strain_ids the model suggested
    suggested_ids   = candidates.filter_map { |c| c[:strain_id] }.uniq
    suggested_names = candidates.map { |c| c[:strain_name] }

    # Fetch by ID first (most reliable)
    strains_by_id   = Strain.where(id: suggested_ids).index_by(&:id)

    # Fall back to fuzzy name match for any unresolved
    unresolved_names = candidates
                         .reject { |c| c[:strain_id] && strains_by_id[c[:strain_id]] }
                         .map { |c| c[:strain_name] }

    strains_by_name = if unresolved_names.any?
                        Strain.where("name ILIKE ANY (ARRAY[?])", unresolved_names)
                              .index_by { |s| s.name.downcase }
                      else
                        {}
                      end

    candidates.map do |c|
      strain = strains_by_id[c[:strain_id]] ||
               strains_by_name[c[:strain_name].downcase]

      c.merge(
        strain_id:   strain&.id,
        strain_name: strain&.name || c[:strain_name]
      )
    end
  end

  # -------------------------------------------------------------------------
  # Client setup
  # -------------------------------------------------------------------------

  def build_client
    OpenAI::Client.new(
      access_token: openai_api_key,
      request_timeout: 60
    )
  end

  def openai_api_key
    Rails.application.credentials.dig(:openai, :api_key) ||
      ENV.fetch('OPENAI_API_KEY') { raise Error, "OpenAI API key not configured" }
  end
end