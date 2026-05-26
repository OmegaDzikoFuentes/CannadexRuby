# app/models/strain_suggestion.rb
class StrainSuggestion < ApplicationRecord
  belongs_to :user
  belongs_to :reviewed_by, class_name: 'User', optional: true, foreign_key: 'reviewed_by_user_id'

  validates :suggested_name, presence: true, length: { maximum: 100 }
  validates :status, inclusion: { in: %w[pending approved rejected] }

  scope :pending,  -> { where(status: 'pending') }
  scope :approved, -> { where(status: 'approved') }
  scope :rejected, -> { where(status: 'rejected') }

  def approve!(admin_user, notes = nil)
    transaction do
      update!(
        status:      'approved',
        reviewed_by: admin_user,
        admin_notes: notes,
        reviewed_at: Time.current
      )

      strain = Strain.create!(
        name:        suggested_name,
        description: description,
        genetics:    genetics,
        effects:     effects,
        flavors:     flavors,
        category:    Category.find_by(name: 'User Contributed') || Category.first,
        data_source: 'user_contributed',
        verified:    false
      )

      # Use award_xp! helper instead of update_column
      user.award_xp!(25)

      # Notify the user their suggestion was approved
      Notification.deliver_to(
        user,
        type:       'system',
        title:      "Your strain suggestion was approved! 🌿",
        body:       "#{suggested_name} has been added to the Cannadex.",
        notifiable: strain,
        data:       { strain_id: strain.id, strain_name: strain.name }
      )

      strain
    end
  end

  def reject!(admin_user, notes)
    update!(
      status:      'rejected',
      reviewed_by: admin_user,
      admin_notes: notes,
      reviewed_at: Time.current
    )

    Notification.deliver_to(
      user,
      type:  'system',
      title: "Your strain suggestion was not approved",
      body:  notes.present? ? "Admin note: #{notes}" : "#{suggested_name} was not added at this time.",
      data:  { suggested_name: suggested_name }
    )
  end
end