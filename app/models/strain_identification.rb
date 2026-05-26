# app/models/strain_identification.rb
class StrainIdentification < ApplicationRecord
    belongs_to :photo
    belongs_to :user
    belongs_to :matched_strain,    class_name: 'Strain', optional: true
    belongs_to :confirmed_by_user, class_name: 'User',   optional: true, foreign_key: :confirmed_by_user_id
  
    # ---------------------------------------------------------------------------
    # Validations
    # ---------------------------------------------------------------------------
    STATUSES = %w[
      pending
      processing
      matched
      low_confidence
      unmatched
      user_confirmed
      user_rejected
      failed
    ].freeze
  
    validates :status, inclusion: { in: STATUSES }
    validates :attempt_number, numericality: { greater_than: 0 }
    validates :confidence, numericality: {
      greater_than_or_equal_to: 0,
      less_than_or_equal_to: 1
    }, allow_nil: true
  
    # ---------------------------------------------------------------------------
    # Scopes
    # ---------------------------------------------------------------------------
    scope :pending,         -> { where(status: 'pending') }
    scope :processing,      -> { where(status: 'processing') }
    scope :matched,         -> { where(status: 'matched') }
    scope :low_confidence,  -> { where(status: 'low_confidence') }
    scope :unmatched,       -> { where(status: 'unmatched') }
    scope :user_confirmed,  -> { where(status: 'user_confirmed') }
    scope :user_rejected,   -> { where(status: 'user_rejected') }
    scope :failed,          -> { where(status: 'failed') }
    scope :confirmed,       -> { where(status: %w[matched user_confirmed]) }
    scope :needs_review,    -> { where(status: %w[low_confidence unmatched]) }
    scope :recent,          -> { order(created_at: :desc) }
  
    # Filter by confidence level
    scope :high_confidence,  -> { where('confidence >= ?', 0.85) }
    scope :low_conf_range,   -> { where(confidence: 0.50..0.74) }
    scope :above_threshold,  -> { where('confidence >= confidence_threshold') }
  
    # Filter by model
    scope :by_model, ->(name) { where(model_name: name) }
  
    # Filter by visual features (jsonb)
    scope :with_visual_feature, ->(key, value) {
      where("visual_features->>:key = :value", key: key, value: value)
    }
  
    # Filter by candidate strain
    scope :with_candidate_strain, ->(strain_id) {
      where("candidates @> ?", [{ strain_id: strain_id }].to_json)
    }
  
    # ---------------------------------------------------------------------------
    # State machine methods
    # ---------------------------------------------------------------------------
  
    def process!(model_response:, candidates:, visual_features: {}, model_name: nil, model_version: nil, processing_ms: nil)
      top = candidates.first || {}
      confidence_val = top['confidence']&.to_f
  
      new_status = if confidence_val.nil?
                     'unmatched'
                   elsif confidence_val >= confidence_threshold
                     'matched'
                   else
                     'low_confidence'
                   end
  
      matched = if new_status == 'matched' && top['strain_id']
                  Strain.find_by(id: top['strain_id'])
                end
  
      update!(
        status:          new_status,
        confidence:      confidence_val,
        candidates:      candidates,
        visual_features: visual_features,
        model_response:  model_response,
        model_name:      model_name,
        model_version:   model_version,
        matched_strain:  matched,
        processed_at:    Time.current,
        processing_ms:   processing_ms
      )
  
      photo.complete_analysis!(visual_features) if new_status == 'matched'
  
      self
    end
  
    def fail!(error_info = {})
      update!(
        status:         'failed',
        model_response: error_info,
        processed_at:   Time.current
      )
      photo.fail_analysis!
    end
  
    # User accepts the top match or a specific strain
    def confirm!(confirming_user, strain: nil, notes: nil)
      strain ||= matched_strain
      raise ArgumentError, "No strain to confirm" unless strain
  
      update!(
        status:              'user_confirmed',
        matched_strain:      strain,
        confirmed_by_user:   confirming_user,
        confirmed_at:        Time.current,
        user_notes:          notes
      )
  
      # Wire the confirmed strain back to the encounter if not already set
      encounter = photo.encounter
      if encounter.strain_id.nil? || encounter.strain != strain
        encounter.update!(strain: strain)
      end
    end
  
    def reject!(rejecting_user, notes: nil)
      update!(
        status:            'user_rejected',
        confirmed_by_user: rejecting_user,
        confirmed_at:      Time.current,
        user_notes:        notes
      )
    end
  
    # ---------------------------------------------------------------------------
    # Helpers
    # ---------------------------------------------------------------------------
  
    def confirmed?
      %w[matched user_confirmed].include?(status)
    end
  
    def needs_review?
      %w[low_confidence unmatched].include?(status)
    end
  
    def top_candidate
      candidates.first
    end
  
    def top_candidate_strain
      return nil unless top_candidate&.dig('strain_id')
      Strain.find_by(id: top_candidate['strain_id'])
    end
  
    def candidate_strains
      strain_ids = candidates.filter_map { |c| c['strain_id'] }
      Strain.where(id: strain_ids).index_by(&:id)
    end
  
    def confidence_percent
      return nil unless confidence
      (confidence * 100).round(1)
    end
  
    def high_confidence?
      confidence.present? && confidence >= confidence_threshold
    end
  
    def color_profile
      visual_features['color_profile'] || []
    end
  
    def trichome_density
      visual_features['trichome_density']
    end
  
    def bud_structure
      visual_features['bud_structure']
    end
  end