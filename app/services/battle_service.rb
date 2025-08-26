# app/services/battle_service.rb
class BattleService
    def initialize(challenger, opponent)
      @challenger = challenger
      @opponent = opponent
    end
    
    def create_battle(strain_ids)
      return { success: false, error: 'Must select 3 strains' } if strain_ids.size != 3
      return { success: false, error: 'Users must be friends' } unless friends?
      
      # Check if challenger has access to these strains
      challenger_strains = @challenger.strains.where(id: strain_ids)
      return { success: false, error: 'Invalid strain selection' } if challenger_strains.size != 3
      
      battle = nil
      ActiveRecord::Base.transaction do
        battle = Battle.create!(
          challenger: @challenger,
          opponent: @opponent,
          status: 'pending'
        )
        
        strain_ids.each_with_index do |strain_id, index|
          battle.battle_strains.create!(
            user: @challenger,
            strain_id: strain_id,
            position: index + 1
          )
        end
      end
      
      { success: true, battle: battle }
    rescue => e
      { success: false, error: e.message }
    end
    
    def accept_battle(battle, strain_ids)
      return { success: false, error: 'Must select 3 strains' } if strain_ids.size != 3
      return { success: false, error: 'Battle cannot be accepted' } unless battle.can_be_accepted?
      
      # Check if opponent has access to these strains
      opponent_strains = @opponent.strains.where(id: strain_ids)
      return { success: false, error: 'Invalid strain selection' } if opponent_strains.size != 3
      
      ActiveRecord::Base.transaction do
        # Add opponent's strains
        strain_ids.each_with_index do |strain_id, index|
          battle.battle_strains.create!(
            user: @opponent,
            strain_id: strain_id,
            position: index + 1
          )
        end
        
        # Accept and conduct the battle
        battle.accept!
      end
      
      { success: true, battle: battle.reload }
    rescue => e
      { success: false, error: e.message }
    end
    
    private
    
    def friends?
      Friendship.exists?(user: @challenger, friend: @opponent, status: 'accepted')
    end
  end
  