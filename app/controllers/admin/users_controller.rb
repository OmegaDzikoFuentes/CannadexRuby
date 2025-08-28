# app/controllers/admin/users_controller.rb
class Admin::UsersController < Admin::ApplicationController
    load_and_authorize_resource
    before_action :find_user, only: [:show, :update, :destroy, :toggle_admin, :verify_age]
    
    def index
      users = User.includes(avatar_attachment: :blob)
                 .order(created_at: :desc)
                 .page(params[:page]).per(50)
      
      render json: {
        users: users.map { |u| admin_user_data(u) },
        pagination: pagination_data(users)
      }
    end
    
    def show
      render json: { user: detailed_admin_user_data(@user) }
    end
    
    def update
      if @user.update(admin_user_params)
        render json: { user: admin_user_data(@user), message: 'User updated successfully' }
      else
        render json: { errors: @user.errors }, status: :unprocessable_entity
      end
    end
    
    def destroy
      @user.destroy
      render json: { message: 'User deleted successfully' }
    end
    
    def toggle_admin
      @user.update!(admin: !@user.admin?)
      render json: { 
        user: admin_user_data(@user),
        message: "User #{@user.admin? ? 'granted' : 'revoked'} admin access"
      }
    end
    
    def verify_age
      @user.update!(age_verified: true, age_verified_at: Time.current)
      render json: {
        user: admin_user_data(@user),
        message: 'User age verified'
      }
    end
    
    private
    
    def find_user
      @user = User.find(params[:id])
    end
    
    def admin_user_params
      params.permit(:first_name, :last_name, :username, :email, :bio, :profile_public,
                    :location_sharing_enabled, :age_verified, :admin)
    end
    
    def admin_user_data(user)
      {
        id: user.id,
        username: user.username,
        email: user.email,
        full_name: user.full_name,
        level: user.level,
        total_encounters: user.total_encounters,
        battles_won: user.battles_won,
        age_verified: user.age_verified?,
        admin: user.admin?,
        created_at: user.created_at,
        last_login: nil # You'd need to track this
      }
    end
    
    def detailed_admin_user_data(user)
      data = admin_user_data(user)
      data.merge({
        bio: user.bio,
        phone: user.phone,
        location: user.location ? [user.location.lat, user.location.lon] : nil,
        city: user.city,
        state: user.state,
        country: user.country,
        settings: {
          profile_public: user.profile_public?,
          location_sharing_enabled: user.location_sharing_enabled?,
          battle_notifications: user.battle_notifications?,
          email_notifications: user.email_notifications?
        },
        stats: {
          friends_count: user.friends.count,
          achievements_count: user.achievements.unlocked.count,
          recent_encounters: user.encounters.count('created_at > ?', 30.days.ago)
        }
      })
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