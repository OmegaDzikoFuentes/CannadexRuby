class BattlesController < ApplicationController
    before_action :authenticate_user!
    before_action :set_battle, only: [:show, :update, :destroy, :accept, :cancel]
    before_action :ensure_own_battle, only: [:update, :destroy, :cancel]
  
    # GET /battles
    def index
      @battles = current_user.battles.includes(:challenger, :opponent, :winner)
                             .order(created_at: :desc)
                             .page(params[:page]).per(10)
  
      render json: {
        battles: @battles.map { |b| battle_json(b) },
        pagination: pagination_info(@battles),
        stats: current_user.battle_stats
      }
    end
  
    # GET /battles/:id
    def show
      render json: {
        battle: detailed_battle_json(@battle),
        rounds: @battle.battle_rounds.map { |r| round_json(r) },
        strains: @battle.battle_strains.group_by(&:user_id).transform_values do |strains|
          strains.map { |bs| battle_strain_json(bs) }
        end
      }
    end
  
    # POST /battles
    def create
      @opponent = User.find(params[:opponent_id])
      unless current_user.friends.include?(@opponent)
        return render json: { error: 'Must be friends to battle' }, status: :forbidden
      end
  
      @battle = current_user.challenged_battles.build(opponent: @opponent, status: 'pending')
  
      if @battle.save
        BattleNotificationJob.perform_later(@opponent.id, 'new_challenge', battle_id: @battle.id)
  
        render json: {
          message: 'Battle challenge created',
          battle: battle_json(@battle)
        }, status: :created
      else
        render json: {
          error: 'Failed to create battle',
          errors: @battle.errors.full_messages
        }, status: :unprocessable_entity
      end
    end
  
    # PUT /battles/:id/accept
    def accept
      unless @battle.can_be_accepted? && @battle.opponent == current_user
        return render json: { error: 'Cannot accept this battle' }, status: :forbidden
      end
  
      if @battle.accept!
        render json: {
          message: 'Battle accepted and conducted',
          battle: detailed_battle_json(@battle)
        }
      else
        render json: { error: 'Failed to accept battle' }, status: :unprocessable_entity
      end
    end
  
    # PUT /battles/:id/cancel
    def cancel
      if @battle.cancel!
        render json: { message: 'Battle cancelled successfully' }
      else
        render json: { error: 'Failed to cancel battle' }, status: :unprocessable_entity
      end
    end
  
    # DELETE /battles/:id
    def destroy
      if @battle.destroy
        render json: { message: 'Battle deleted successfully' }
      else
        render json: { error: 'Failed to delete battle' }, status: :unprocessable_entity
      end
    end
  
    private
  
    def set_battle
      @battle = Battle.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      render json: { error: 'Battle not found' }, status: :not_found
    end
  
    def ensure_own_battle
      unless @battle.participants.include?(current_user)
        render json: { error: 'Not authorized' }, status: :forbidden
      end
    end
  
    def battle_json(battle)
      {
        id: battle.id,
        status: battle.status,
        challenger: user_info(battle.challenger),
        opponent: user_info(battle.opponent),
        winner: battle.winner ? user_info(battle.winner) : nil,
        score: "#{battle.challenger_score} - #{battle.opponent_score}",
        battled_at: battle.battled_at
      }
    end
  
    def detailed_battle_json(battle)
      battle_json(battle).merge(
        expires_at: battle.expires_at,
        expired: battle.expired?,
        results: battle.battle_results,
        can_accept: battle.can_be_accepted? && battle.opponent == current_user
      )
    end
  
    def round_json(round)
      {
        round_number: round.round_number,
        challenger_strain: strain_info(round.challenger_strain),
        opponent_strain: strain_info(round.opponent_strain),
        winner_strain: strain_info(round.winner_strain),
        results: round.round_results
      }
    end
  
    def battle_strain_json(bs)
      {
        position: bs.position,
        strain: strain_info(bs.strain)
      }
    end
  
    def user_info(user)
      {
        id: user.id,
        username: user.username,
        level: user.level
      }
    end
  
    def strain_info(strain)
      {
        id: strain.id,
        name: strain.name,
        category: strain.category.name,
        average_rating: strain.average_overall_rating
      }
    end
  
    def pagination_info(collection)
      {
        current_page: collection.current_page,
        total_pages: collection.total_pages,
        total_count: collection.total_count
      }
    end
  end