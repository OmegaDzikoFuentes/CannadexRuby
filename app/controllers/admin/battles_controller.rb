# app/controllers/admin/battles_controller.rb
class Admin::BattlesController < Admin::ApplicationController
    def index
      battles = Battle.includes(:challenger, :opponent, :winner)
                     .order(created_at: :desc)
                     .page(params[:page]).per(50)
      
      render json: {
        battles: battles.map { |b| admin_battle_data(b) },
        pagination: pagination_data(battles)
      }
    end
    
    def show
      battle = Battle.find(params[:id])
      render json: { battle: detailed_admin_battle_data(battle) }
    end
    
    private
    
    def admin_battle_data(battle)
      {
        id: battle.id,
        challenger: {
          id: battle.challenger.id,
          username: battle.challenger.username
        },
        opponent: {
          id: battle.opponent.id,
          username: battle.opponent.username
        },
        status: battle.status,
        winner: battle.winner ? {
          id: battle.winner.id,
          username: battle.winner.username
        } : nil,
        score: "#{battle.challenger_score}-#{battle.opponent_score}",
        created_at: battle.created_at,
        battled_at: battle.battled_at
      }
    end
    
    def detailed_admin_battle_data(battle)
      admin_battle_data(battle).merge({
        rounds: battle.battle_rounds.order(:round_number).map do |round|
          {
            round_number: round.round_number,
            challenger_strain: round.challenger_strain.name,
            opponent_strain: round.opponent_strain.name,
            winner_strain: round.winner_strain.name,
            results: round.round_results
          }
        end,
        expires_at: battle.expires_at,
        battle_results: battle.battle_results
      })
    end
  end
  