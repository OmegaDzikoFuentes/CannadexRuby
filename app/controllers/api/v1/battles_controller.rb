# app/controllers/api/v1/battles_controller.rb
class Api::V1::BattlesController < Api::V1::ApplicationController
    before_action :find_battle, only: [:show, :accept, :decline, :cancel]
    
    def index
      battles = current_user.battles
                           .includes(:challenger, :opponent, :winner, battle_strains: :strain)
                           .order(created_at: :desc)
                           .page(params[:page])
                           .per(20)
      
      render_success({
        battles: battles.map { |b| battle_data(b) },
        pagination: pagination_data(battles)
      })
    end
    
    def show
      render_success({ battle: detailed_battle_data(@battle) })
    end
    
    def create
      opponent = User.find(params[:opponent_id])
      challenger_strain_ids = params[:strain_ids] || []
      
      battle_service = BattleService.new(current_user, opponent)
      result = battle_service.create_battle(challenger_strain_ids)
      
      if result[:success]
        render_success(
          { battle: battle_data(result[:battle]) },
          'Battle challenge sent!'
        )
      else
        render_error(result[:error])
      end
    end
    
    def accept
      return render_unauthorized unless can_respond_to_battle?
      
      opponent_strain_ids = params[:strain_ids] || []
      battle_service = BattleService.new(@battle.challenger, current_user)
      result = battle_service.accept_battle(@battle, opponent_strain_ids)
      
      if result[:success]
        render_success(
          { battle: detailed_battle_data(result[:battle]) },
          'Battle accepted and completed!'
        )
      else
        render_error(result[:error])
      end
    end
    
    def decline
      return render_unauthorized unless can_respond_to_battle?
      
      @battle.update!(status: 'cancelled')
      render_success({}, 'Battle declined')
    end
    
    def cancel
      return render_unauthorized unless @battle.challenger == current_user
      return render_error('Cannot cancel active or completed battles') unless @battle.status == 'pending'
      
      @battle.update!(status: 'cancelled')
      render_success({}, 'Battle cancelled')
    end
    
    def pending
      battles = current_user.opponent_battles.pending
                           .includes(:challenger, battle_strains: :strain)
                           .order(created_at: :desc)
      
      render_success({
        battles: battles.map { |b| battle_data(b) }
      })
    end
    
    def history
      battles = current_user.battles.completed
                           .includes(:challenger, :opponent, :winner, battle_rounds: [:challenger_strain, :opponent_strain])
                           .order(battled_at: :desc)
                           .page(params[:page])
                           .per(20)
      
      render_success({
        battles: battles.map { |b| detailed_battle_data(b) },
        pagination: pagination_data(battles)
      })
    end
    
    private
    
    def find_battle
      @battle = Battle.find(params[:id])
    end
    
    def can_respond_to_battle?
      @battle.opponent == current_user && @battle.can_be_accepted?
    end
    
    def battle_data(battle)
      {
        id: battle.id,
        challenger: user_summary(battle.challenger),
        opponent: user_summary(battle.opponent),
        status: battle.status,
        winner: battle.winner ? user_summary(battle.winner) : nil,
        score: "#{battle.challenger_score}-#{battle.opponent_score}",
        expires_at: battle.expires_at,
        battled_at: battle.battled_at,
        created_at: battle.created_at
      }
    end
    
    def detailed_battle_data(battle)
      data = battle_data(battle)
      
      if battle.battle_rounds.any?
        data[:rounds] = battle.battle_rounds.order(:round_number).map do |round|
          {
            round_number: round.round_number,
            challenger_strain: strain_summary(round.challenger_strain),
            opponent_strain: strain_summary(round.opponent_strain),
            winner_strain: strain_summary(round.winner_strain),
            results: round.round_results
          }
        end
      end
      
      if battle.battle_strains.any?
        data[:strains] = {
          challenger: battle.strains_for_user(battle.challenger).map { |bs| strain_summary(bs.strain) },
          opponent: battle.strains_for_user(battle.opponent).map { |bs| strain_summary(bs.strain) }
        }
      end
      
      data
    end
    
    def user_summary(user)
      {
        id: user.id,
        username: user.username,
        level: user.level,
        battles_won: user.battles_won,
        battles_lost: user.battles_lost,
        win_rate: user.win_rate
      }
    end
    
    def strain_summary(strain)
      {
        id: strain.id,
        name: strain.name,
        category: strain.category.name,
        average_rating: strain.average_overall_rating
      }
    end
  end