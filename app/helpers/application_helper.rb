module ApplicationHelper
    def turbo_native?
      request.user_agent.include?("Turbo Native")  # Detects native app UA
    end
  end