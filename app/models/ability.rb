class Ability
    include CanCan::Ability
  
    def initialize(user)
      # Guest user (not logged in)
      return unless user
  
      if user.admin?
        can :manage, :all  # Admins can do everything
        can :access, :admin_dashboard
      else
        # Regular user permissions
        can :read, Strain
        can :create, Encounter
        can :read, Battle
        can :create, Battle
        can :read, User, profile_public: true
        can :read, User, id: user.id # Can read own profile even if private
        can :update, User, id: user.id # Can update own profile
        can :manage, Friendship, user_id: user.id
        can :create, StrainSuggestion
        # Add more rules as needed
        
        # Explicitly deny admin access
        cannot :access, :admin_dashboard
      end
    end
  end