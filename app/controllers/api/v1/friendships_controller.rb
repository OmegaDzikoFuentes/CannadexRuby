# app/controllers/api/v1/friendships_controller.rb
class Api::V1::FriendshipsController < Api::V1::ApplicationController
    before_action :find_friendship, only: [:show, :update, :destroy]
    
    def index
      friends = current_user.friends
                           .includes(avatar_attachment: :blob)
                           .order(:username)
                           .page(params[:page]).per(20)
      
      render_success({
        friends: friends.map { |f| friend_data(f) },
        pagination: pagination_data(friends)
      })
    end
    
    def create
      friend = User.find(params[:friend_id])
      
      # Check if friendship already exists
      existing_friendship = Friendship.find_by(user: current_user, friend: friend) ||
                           Friendship.find_by(user: friend, friend: current_user)
      
      if existing_friendship
        case existing_friendship.status
        when 'accepted'
          return render_error('Already friends with this user')
        when 'pending'
          return render_error('Friend request already sent')
        when 'blocked'
          return render_error('Cannot send friend request')
        end
      end
      
      friendship = current_user.friendships.build(friend: friend, status: 'pending')
      
      if friendship.save
        # Create notification for the friend
        NotificationService.create_friend_request_notification(friend, current_user)
        
        render_success(
          { friendship: friendship_data(friendship) },
          'Friend request sent!'
        )
      else
        render json: {
          success: false,
          message: 'Failed to send friend request',
          errors: friendship.errors
        }, status: :unprocessable_entity
      end
    end
    
    def update
      case params[:action_type]
      when 'accept'
        if @friendship.accept!
          render_success(
            { friendship: friendship_data(@friendship) },
            'Friend request accepted!'
          )
        else
          render_error('Failed to accept friend request')
        end
      when 'block'
        @friendship.block!
        render_success({}, 'User blocked')
      else
        render_error('Invalid action type')
      end
    end
    
    def destroy
      @friendship.destroy
      
      # Also destroy inverse friendship
      inverse_friendship = Friendship.find_by(user: @friendship.friend, friend: current_user)
      inverse_friendship&.destroy
      
      render_success({}, 'Friendship ended')
    end
    
    def requests
      # Incoming friend requests
      requests = Friendship.includes(:user)
                          .where(friend: current_user, status: 'pending')
                          .order(requested_at: :desc)
      
      render_success({
        requests: requests.map { |r| request_data(r) }
      })
    end
    
    def pending
      # Outgoing friend requests
      pending_requests = current_user.friendships
                                    .includes(:friend)
                                    .where(status: 'pending')
                                    .order(requested_at: :desc)
      
      render_success({
        pending_requests: pending_requests.map { |r| pending_request_data(r) }
      })
    end
    
    private
    
    def find_friendship
      @friendship = current_user.friendships.find(params[:id])
    end
    
    def friend_data(friend)
      {
        id: friend.id,
        username: friend.username,
        full_name: friend.full_name,
        level: friend.level,
        battles_won: friend.battles_won,
        total_encounters: friend.total_encounters,
        online_status: 'offline', # You could implement online status tracking
        avatar_url: friend.avatar.attached? ? rails_blob_url(friend.avatar) : nil
      }
    end
    
    def friendship_data(friendship)
      {
        id: friendship.id,
        friend: friend_data(friendship.friend),
        status: friendship.status,
        requested_at: friendship.requested_at,
        accepted_at: friendship.accepted_at
      }
    end
    
    def request_data(request)
      {
        id: request.id,
        user: {
          id: request.user.id,
          username: request.user.username,
          full_name: request.user.full_name,
          level: request.user.level,
          avatar_url: request.user.avatar.attached? ? rails_blob_url(request.user.avatar) : nil
        },
        requested_at: request.requested_at
      }
    end
    
    def pending_request_data(request)
      {
        id: request.id,
        friend: {
          id: request.friend.id,
          username: request.friend.username,
          full_name: request.friend.full_name
        },
        requested_at: request.requested_at
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