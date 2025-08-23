# app/models/strain_suggestion.rb
class StrainSuggestion < ApplicationRecord
    belongs_to :user
    belongs_to :reviewed_by, class_name: 'User', optional: true, foreign_key: 'reviewed_by_user_id'
    
    validates :suggested_name, presence: true, length: { maximum: 100 }
    validates :status, inclusion: { in: %w[pending approved rejected] }
    
    scope :pending, -> { where(status: 'pending') }
    scope :approved, -> { where(status: 'approved') }
    scope :rejected, -> { where(status: 'rejected') }
    
    def approve!(admin_user, notes = nil)
      transaction do
        update!(
          status: 'approved',
          reviewed_by: admin_user,
          admin_notes: notes,
          reviewed_at: Time.current
        )
        
        # Create the actual strain
        strain = Strain.create!(
          name: suggested_name,
          description: description,
          genetics: genetics,
          effects: effects,
          flavors: flavors,
          category: Category.find_by(name: 'User Contributed') || Category.first,
          data_source: 'user_contributed',
          verified: false
        )
        
        # Award XP to suggesting user
        user.update_column(:experience_points, user.experience_points + 25)
        user.check_level_up!
        
        strain
      end
    end
    
    def reject!(admin_user, notes)
      update!(
        status: 'rejected',
        reviewed_by: admin_user,
        admin_notes: notes,
        reviewed_at: Time.current
      )
    end
  end