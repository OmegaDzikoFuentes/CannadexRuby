# app/controllers/api/v1/strain_suggestions_controller.rb
class Api::V1::StrainSuggestionsController < Api::V1::ApplicationController
    before_action :find_suggestion, only: [:show]
    
    def index
      suggestions = current_user.strain_suggestions
                               .order(created_at: :desc)
                               .page(params[:page]).per(20)
      
      render_success({
        suggestions: suggestions.map { |s| suggestion_data(s) },
        pagination: pagination_data(suggestions)
      })
    end
    
    def show
      render_success({ suggestion: detailed_suggestion_data(@suggestion) })
    end
    
    def create
      suggestion = current_user.strain_suggestions.build(suggestion_params)
      
      if suggestion.save
        render_success(
          { suggestion: suggestion_data(suggestion) },
          'Strain suggestion submitted successfully!'
        )
      else
        render json: {
          success: false,
          message: 'Failed to submit strain suggestion',
          errors: suggestion.errors
        }, status: :unprocessable_entity
      end
    end
    
    private
    
    def find_suggestion
      @suggestion = current_user.strain_suggestions.find(params[:id])
    end
    
    def suggestion_params
      params.permit(:suggested_name, :description, :genetics, effects: [], flavors: [])
    end
    
    def suggestion_data(suggestion)
      {
        id: suggestion.id,
        suggested_name: suggestion.suggested_name,
        description: suggestion.description,
        genetics: suggestion.genetics,
        effects: suggestion.effects,
        flavors: suggestion.flavors,
        status: suggestion.status,
        created_at: suggestion.created_at
      }
    end
    
    def detailed_suggestion_data(suggestion)
      data = suggestion_data(suggestion)
      
      if suggestion.reviewed_by.present?
        data[:review] = {
          reviewed_by: {
            id: suggestion.reviewed_by.id,
            username: suggestion.reviewed_by.username
          },
          admin_notes: suggestion.admin_notes,
          reviewed_at: suggestion.reviewed_at
        }
      end
      
      data
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