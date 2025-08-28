# config/routes.rb
Rails.application.routes.draw do
  # API routes
  namespace :api do
    namespace :v1 do
      # Authentication
      post 'auth/login', to: 'authentication#login'
      post 'auth/register', to: 'authentication#register'
      delete 'auth/logout', to: 'authentication#logout'
      post 'auth/forgot_password', to: 'authentication#forgot_password'
      post 'auth/reset_password', to: 'authentication#reset_password'
      
      # Age verification
      post 'auth/verify_age', to: 'authentication#verify_age'
      
      # User management
      resources :users, only: [:show, :update] do
        member do
          get :profile
          get :encounters
          get :battles
          get :achievements
          get :activity_feed
        end
        
        collection do
          get :nearby
          get :search
        end
      end
      
      # Encounters (core bud catalog)
      resources :encounters do
        member do
          post :regenerate_card
          patch :toggle_privacy
        end
        
        collection do
          get :nearby
          get :public_feed
          get :friends_feed
        end
      end
      
      # Strains
      resources :strains, only: [:index, :show] do
        member do
          get :community_stats
          get :similar
        end
        
        collection do
          get :search
          get :popular
          get :recently_added
        end
      end
      
      # Strain suggestions
      resources :strain_suggestions, only: [:create, :index, :show]
      
      # Categories
      resources :categories, only: [:index, :show]
      
      # Friendships
      resources :friendships, only: [:index, :create, :update, :destroy] do
        collection do
          get :requests
          get :pending
        end
      end
      
      # Battles
      resources :battles, only: [:index, :show, :create] do
        member do
          post :accept
          post :decline
          delete :cancel
        end
        
        collection do
          get :pending
          get :active
          get :completed
          get :history
        end
      end
      
      # Achievements
      resources :achievements, only: [:index, :show] do
        member do
          post :claim
        end
        
        collection do
          get :unlocked
          get :available
        end
      end
      
      # Recommendations
      get 'recommendations/strains', to: 'recommendations#strains'
      get 'recommendations/users', to: 'recommendations#users'
      
      # Search
      get 'search', to: 'search#index'
      get 'search/strains', to: 'search#strains'
      get 'search/users', to: 'search#users'
      
      # Analytics/Stats
      get 'stats/user', to: 'stats#user_stats'
      get 'stats/community', to: 'stats#community_stats'
      
      # File uploads
      post 'uploads/encounter_photos', to: 'uploads#encounter_photos'
      post 'uploads/avatar', to: 'uploads#avatar'
    end
  end
  
  # Admin routes
  namespace :admin do
    resources :users do
      member do
        patch :toggle_admin
        patch :verify_age
      end
    end
    
    resources :strains do
      member do
        patch :verify
        patch :toggle_active
      end
    end
    
    resources :strain_suggestions do
      member do
        patch :approve
        patch :reject
      end
    end
    
    resources :encounters, only: [:index, :show, :destroy]
    resources :battles, only: [:index, :show]
    
    # Analytics
    get 'analytics/dashboard', to: 'analytics#dashboard'
    get 'analytics/users', to: 'analytics#users'
    get 'analytics/strains', to: 'analytics#strains'
  end
  
  # Health check
  get 'health', to: 'health#check'
  get '/mobile/home', to: 'mobile#home_screen'
  root 'home#index'
  get 'health', to: 'health#check'
  get '/battle', to: 'battles#index'
end