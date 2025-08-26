class HomeController < ApplicationController
    skip_before_action :authenticate_user!, only: [:index]
  
    # GET /
    def index
      @app_info = AppInfo.current
      @banner = BannerPhoto.current_banner
  
      render 'home/index', locals: {
        app_name: @app_info.name,
        tagline: @app_info.tagline,
        banner_image: @banner&.image_url
      }
    end
  end