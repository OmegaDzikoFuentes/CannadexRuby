# app/models/friendship.rb
class Friendship < ApplicationRecord
  belongs_to :user
  belongs_to :friend, class_name: 'User'

  validates :user_id, uniqueness: { scope: :friend_id }
  validates :status, inclusion: { in: %w[pending accepted blocked] }
  validate  :cannot_friend_self

  scope :pending,  -> { where(status: 'pending') }
  scope :accepted, -> { where(status: 'accepted') }
  scope :blocked,  -> { where(status: 'blocked') }

  after_create :notify_friend_request, if: :pending?
  after_update :handle_status_change

  def accept!
    return false unless pending?

    transaction do
      update!(status: 'accepted', accepted_at: Time.current)
      create_inverse_friendship unless inverse_friendship_exists?

      notify_friend_accepted

      [user, friend].each do |u|
        CheckAchievementsJob.perform_later(u, 'friendship_created')
      end
    end
  end

  def block!
    update!(status: 'blocked')
    inverse_friendship&.update!(status: 'blocked')
  end

  def pending?
    status == 'pending'
  end

  def accepted?
    status == 'accepted'
  end

  def blocked?
    status == 'blocked'
  end

  private

  def cannot_friend_self
    errors.add(:friend, "can't friend yourself") if user_id == friend_id
  end

  def inverse_friendship_exists?
    Friendship.exists?(user: friend, friend: user)
  end

  def create_inverse_friendship
    Friendship.create!(
      user:         friend,
      friend:       user,
      status:       'accepted',
      requested_at: Time.current,
      accepted_at:  Time.current
    )
  end

  def handle_status_change
    return unless saved_change_to_status?
    case status
    when 'accepted'
      create_inverse_friendship unless inverse_friendship_exists?
      notify_friend_accepted
    when 'blocked'
      inverse_friendship&.update!(status: 'blocked')
    end
  end

  def inverse_friendship
    Friendship.find_by(user: friend, friend: user)
  end

  def notify_friend_request
    Notification.deliver_to(
      friend,
      type:       'friend_request',
      title:      "#{user.username} sent you a friend request",
      notifiable: self,
      data:       { from_username: user.username, from_user_id: user.id }
    )
  end

  def notify_friend_accepted
    Notification.deliver_to(
      user,
      type:       'friend_accepted',
      title:      "#{friend.username} accepted your friend request 🎉",
      notifiable: self,
      data:       { from_username: friend.username, from_user_id: friend.id }
    )
  end
end