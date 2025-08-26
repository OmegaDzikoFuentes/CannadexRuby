# app/controllers/api/v1/users_controller.rb
class Api::V1::UsersController < Api::V1::ApplicationController
    before_action :find_user, only: [:show, :update, :profile, :encounters, :battles, :achievements, :activity_feed]
    
    def show
      return render_unauthorized unless can_view_profile?
      render_success({ user: user_data(@user) })
    end
    
    def update
      return render_unauthorized unless @user == current_user
      
      if @user.update(user_params)
        render_success({ user: user_data(@user) }, 'Profile updated successfully')
      else
        render json: {
          success: false,
          message: 'Failed to update profile',
          errors: @user.errors
        }, status: :unprocessable_entity
      end
    end
    
    def profile
      return render_unauthorized unless can_view_profile?
      
      profile_data = user_data(@user).merge({
        stats: {
          total_encounters: @user.total_encounters,
          unique_strains: @user.strains.distinct.count,
          battles_won: @user.battles_won,
          battles_lost: @user.battles_lost,
          win_rate: @user.win_rate,
          level: @user.level,
          experience_points: @user.experience_points,
          achievements_unlocked: @user.achievements.unlocked.count,
          friends_count: @user.friends.count
        },
        location: @user.show_location_in_profile? ? user_location(@user) : nil,
        recent_encounters: @user.encounters.includes(:strain).limit(5).order(encountered_at: :desc).map { |e| encounter_summary(e) }
      })
      
      render_success({ profile: profile_data })
    end
    
    def encounters
      return render_unauthorized unless can_view_encounters?
      
      encounters = @user.encounters.includes(:strain, photos_attachments: :blob)
                       .order(encountered_at: :desc)
                       .page(params[:page]).per(20)
      
      render_success({
        encounters: encounters.map { |e| encounter_data(e) },
        pagination: pagination_data(encounters)
      })
    end
    
    def battles
      return render_unauthorized unless can_view_battles?
      
      battles = @user.battles.includes(:challenger, :opponent, :winner)
                    .order(created_at: :desc)
                    .page(params[:page]).per(20)
      
      render_success({
        battles: battles.map { |b| battle_data(b) },
        pagination: pagination_data(battles)
      })
    end
    
    def achievements
      return render_unauthorized unless can_view_achievements?
      
      achievements = @user.achievements.order(:is_unlocked, :created_at)
      
      render_success({
        achievements: achievements.map { |a| achievement_data(a) },
        stats: {
          unlocked: achievements.unlocked.count,
          total: achievements.count,
          total_xp_earned: achievements.unlocked.sum(:xp_reward)
        }
      })
    end
    
    def activity_feed
      return render_unauthorized unless can_view_activity?
      
      activities = @user.activities.includes(:trackable)
                       .order(created_at: :desc)
                       .page(params[:page]).per(20)
      
      render_success({
        activities: activities.map { |a| activity_data(a) },
        pagination: pagination_data(activities)
      })
    end
    
    def nearby
      return render_error('Location required') unless current_user.location
      
      radius = params[:radius]&.to_i || 35
      users = User.near_location(current_user.location.lat, current_user.location.lon, radius)
                 .where.not(id: current_user.id)
                 .where(discoverable_by_location: true, profile_public: true)
                 .page(params[:page]).per(20)
      
      render_success({
        users: users.map { |u| user_summary(u) },
        pagination: pagination_data(users)
      })
    end
    
    def search
      query = params[:q]&.strip
      return render_error('Search query required') if query.blank?
      
      users = User.where('username ILIKE ? OR first_name ILIKE ? OR last_name ILIKE ?', 
                        "%#{query}%", "%#{query}%", "%#{query}%")
                 .where(discoverable_by_username: true, profile_public: true)
                 .where.not(id: current_user.id)
                 .limit(20)
      
      render_success({
        users: users.map { |u| user_summary(u) }
      })
    end
    
    private
    
    def find_user
      @user = User.find(params[:id])
    end
    
    def user_params
      params.permit(:first_name, :last_name, :bio, :profile_public, :location_sharing_enabled,
                    :battle_notifications, :email_notifications, :push_notifications,
                    :friend_request_notifications, :achievement_notifications,
                    :show_location_in_profile, :discoverable_by_username, :discoverable_by_location,
                    :city, :state, :country, :latitude, :longitude)
    end
    
    def can_view_profile?
      return true if @user == current_user
      return true if @user.profile_public?
      current_user.friends.include?(@user)
    end
    
    def can_view_encounters?
      @user == current_user || (@user.profile_public? && current_user.friends.include?(@user))
    end
    
    def can_view_battles?
      @user == current_user
    end
    
    def can_view_achievements?
      can_view_profile?
    end
    
    def can_view_activity?
      can_view_profile?
    end
    
    def user_data(user)
      {
        id: user.id,
        first_name: user.first_name,
        last_name: user.last_name,
        full_name: user.full_name,
        username: user.username,
        email: user == current_user ? user.email : nil,
        bio: user.bio,
        level: user.level,
        experience_points: user.experience_points,
        profile_public: user.profile_public?,
        created_at: user.created_at
      }
    end
    
    def user_summary(user)
      {
        id: user.id,
        username: user.username,
        full_name: user.full_name,
        level: user.level,
        battles_won: user.battles_won,
        total_encounters: user.total_encounters
      }
    end
    
    def user_location(user)
      return nil unless user.location && user.show_location_in_profile?
      {
        city: user.city,
        state: user.state,
        country: user.country
      }
    end
    
    def encounter_summary(encounter)
      {
        id: encounter.id,
        strain_name: encounter.strain.name,
        overall_rating: encounter.overall_rating,
        encountered_at: encounter.encountered_at
      }
    end
    
    def encounter_data(encounter)
      # Use same method from encounters_controller
    end
    
    def battle_data(battle)
      # Use same method from battles_controller  
    end
    
    def achievement_data(achievement)
      {
        id: achievement.id,
        achievement_type: achievement.achievement_type,
        title: achievement.title,
        description: achievement.description,
        progress: achievement.progress,
        goal: achievement.goal,
        progress_percentage: achievement.progress_percentage,
        xp_reward: achievement.xp_reward,
        is_unlocked: achievement.is_unlocked?,
        is_claimed: achievement.is_claimed?,
        unlocked_at: achievement.unlocked_at,
        claimed_at: achievement.claimed_at
      }
    end
    
    def activity_data(activity)
      {
        id: activity.id,
        activity_type: activity.activity_type,
        message: activity.formatted_message,
        created_at: activity.created_at,
        trackable_type: activity.trackable_type,
        trackable_id: activity.trackable_id
      }
    end
    
    def pagination_data(collection)
      {
        current_page: collection.current_page,
        total_pages: collection.total_pages,
        total_count: collection.total_count,
        per_page: collection.limit_value
      }
    end
  end