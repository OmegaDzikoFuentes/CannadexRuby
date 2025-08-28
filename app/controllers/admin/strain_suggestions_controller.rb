# app/controllers/admin/strain_suggestions_controller.rb
class Admin::StrainSuggestionsController < Admin::ApplicationController
    load_and_authorize_resource
    before_action :find_suggestion, only: [:show, :approve, :reject]
    
    def index
      suggestions = StrainSuggestion.includes(:user, :reviewed_by)
                                   .order(created_at: :desc)
                                   .page(params[:page]).per(50)
      
      render json: {
        suggestions: suggestions.map { |s| admin_suggestion_data(s) },
        pagination: pagination_data(suggestions)
      }
    end
    
    def show
      render json: { suggestion: detailed_admin_suggestion_data(@suggestion) }
    end
    
    def approve
      strain = @suggestion.approve!(current_user, params[:notes])
      
      render json: {
        suggestion: admin_suggestion_data(@suggestion),
        strain: admin_strain_data(strain),
        message: 'Strain suggestion approved and strain created'
      }
    end
    
    def reject
      @suggestion.reject!(current_user, params[:notes])
      
      render json: {
        suggestion: admin_suggestion_data(@suggestion),
        message: 'Strain suggestion rejected'
      }
    end
    
    private
    
    def find_suggestion
      @suggestion = StrainSuggestion.find(params[:id])
    end
    
    def admin_suggestion_data(suggestion)
      {
        id: suggestion.id,
        suggested_name: suggestion.suggested_name,
        user: {
          id: suggestion.user.id,
          username: suggestion.user.username
        },
        status: suggestion.status,
        created_at: suggestion.created_at,
        reviewed_at: suggestion.reviewed_at
      }
    end
    
    def detailed_admin_suggestion_data(suggestion)
      admin_suggestion_data(suggestion).merge({
        description: suggestion.description,
        genetics: suggestion.genetics,
        effects: suggestion.effects,
        flavors: suggestion.flavors,
        admin_notes: suggestion.admin_notes,
        reviewed_by: suggestion.reviewed_by ? {
          id: suggestion.reviewed_by.id,
          username: suggestion.reviewed_by.username
        } : nil
      })
    end
    
    def admin_strain_data(strain)
      {
        id: strain.id,
        name: strain.name,
        category: strain.category.name,
        verified: strain.verified?
      }
    end
  end