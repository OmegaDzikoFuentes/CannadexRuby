# app/models/battle_round.rb
class BattleRound < ApplicationRecord
    belongs_to :battle
    belongs_to :challenger_strain, class_name: 'Strain'
    belongs_to :opponent_strain, class_name: 'Strain'
    belongs_to :winner_strain, class_name: 'Strain', optional: true
    
    validates :round_number, presence: true, inclusion: { in: 1..3 }
    validates :round_number, uniqueness: { scope: :battle_id }
    validate :strains_are_different
    validate :winner_strain_is_participant
    
    scope :ordered, -> { order(:round_number) }
    
    def round_results_hash
      return {} unless round_results.present?
      JSON.parse(round_results) rescue {}
    end
    
    def challenger_score
      round_results_hash['challenger_score'] || 0.0
    end
    
    def opponent_score  
      round_results_hash['opponent_score'] || 0.0
    end
    
    def winner_username
      round_results_hash['winner']
    end
    
    def challenger_won?
      winner_strain == challenger_strain
    end
    
    def opponent_won?
      winner_strain == opponent_strain
    end
    
    def margin_of_victory
      (challenger_score - opponent_score).abs
    end
    
    def close_round?
      margin_of_victory < 1.0
    end
    
    private
    
    def strains_are_different
      if challenger_strain == opponent_strain
        errors.add(:opponent_strain, "must be different from challenger strain")
      end
    end
    
    def winner_strain_is_participant
      return unless winner_strain
      
      unless [challenger_strain, opponent_strain].include?(winner_strain)
        errors.add(:winner_strain, "must be either the challenger or opponent strain")
      end
    end
  end
  