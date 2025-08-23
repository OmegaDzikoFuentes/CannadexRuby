# app/models/battle_strain.rb
class BattleStrain < ApplicationRecord
    belongs_to :battle
    belongs_to :user
    belongs_to :strain
    
    validates :position, presence: true, inclusion: { in: 1..3 }
    validates :position, uniqueness: { scope: [:battle_id, :user_id] }
    validate :user_is_battle_participant
    validate :user_has_encountered_strain
    
    scope :for_user, ->(user) { where(user: user) }
    scope :ordered, -> { order(:position) }
    scope :by_position, ->(pos) { where(position: pos) }
    
    def self.setup_battle_lineup(battle, challenger_strains, opponent_strains)
      return false unless challenger_strains.size == 3 && opponent_strains.size == 3
      
      transaction do
        challenger_strains.each_with_index do |strain, index|
          create!(
            battle: battle,
            user: battle.challenger,
            strain: strain,
            position: index + 1
          )
        end
        
        opponent_strains.each_with_index do |strain, index|
          create!(
            battle: battle,
            user: battle.opponent,
            strain: strain,
            position: index + 1
          )
        end
      end
      
      true
    rescue ActiveRecord::RecordInvalid
      false
    end
    
    def opponent_strain_for_position
      battle.battle_strains
            .where(position: position)
            .where.not(user: user)
            .first&.strain
    end
    
    def battle_ready?
      strain.present? && user.encounters.exists?(strain: strain)
    end
    
    private
    
    def user_is_battle_participant
      return unless battle && user
      
      unless [battle.challenger_id, battle.opponent_id].include?(user.id)
        errors.add(:user, "must be a participant in this battle")
      end
    end
    
    def user_has_encountered_strain
      return unless user && strain
      
      unless user.encounters.exists?(strain: strain)
        errors.add(:strain, "must be in your Cannadex to use in battle")
      end
    end
  end