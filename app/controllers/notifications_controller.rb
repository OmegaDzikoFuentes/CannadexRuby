class NotificationsController < ApplicationController
    before_action :authenticate_user!
    before_action :set_notification, only: [:show, :mark_read, :destroy]
  
    # GET /notifications
    def index
      @notifications = current_user.notifications
                                  .includes(:notifiable)
                                  .order(created_at: :desc)
                                  .page(params[:page]).per(20)
  
      render json: {
        notifications: @notifications.map { |n| notification_json(n) },
        unread_count: current_user.notifications.unread.count,
        pagination: pagination_info(@notifications)
      }
    end
  
    # GET /notifications/:id
    def show
      @notification.mark_as_read! if @notification.unread?
  
      render json: {
        notification: detailed_notification_json(@notification)
      }
    end
  
    # PUT /notifications/:id/mark_read
    def mark_read
      if @notification.mark_as_read!
        render json: { message: 'Notification marked as read' }
      else
        render json: { error: 'Failed to mark as read' }, status: :unprocessable_entity
      end
    end
  
    # DELETE /notifications/:id
    def destroy
      if @notification.destroy
        render json: { message: 'Notification deleted' }
      else
        render json: { error: 'Failed to delete notification' }, status: :unprocessable_entity
      end
    end
  
    # PUT /notifications/mark_all_read
    def mark_all_read
      unread_count = current_user.notifications.unread.count
      current_user.notifications.unread.update_all(read_at: Time.current)
  
      render json: {
        message: "#{unread_count} notifications marked as read"
      }
    end
  
    # GET /notifications/current
    def current
      @current_notifications = current_user.notifications
                                          .unread
                                          .order(created_at: :desc)
                                          .limit(5)
  
      render json: {
        current_notifications: @current_notifications.map { |n| notification_json(n) },
        total_unread: current_user.notifications.unread.count
      }
    end
  
    private
  
    def set_notification
      @notification = current_user.notifications.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      render json: { error: 'Notification not found' }, status: :not_found
    end
  
    def notification_json(notification)
      {
        id: notification.id,
        type: notification.notification_type,
        message: notification.message,
        read: notification.read?,
        created_at: notification.created_at
      }
    end
  
    def detailed_notification_json(notification)
      notification_json(notification).merge(
        data: notification.data,
        notifiable: notifiable_info(notification.notifiable)
      )
    end
  
    def notifiable_info(notifiable)
      case notifiable
      when Battle
        { type: 'battle', id: notifiable.id, status: notifiable.status }
      when Achievement
        { type: 'achievement', id: notifiable.id, title: notifiable.title }
      else
        { type: notifiable.class.name.downcase, id: notifiable.id }
      end
    end
  
    def pagination_info(collection)
      {
        current_page: collection.current_page,
        total_pages: collection.total_pages,
        total_count: collection.total_count
      }
    end
  end