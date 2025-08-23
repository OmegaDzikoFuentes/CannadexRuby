# db/migrate/016_add_rating_constraints.rb
class AddRatingConstraints < ActiveRecord::Migration[8.0]
  def change
    # Add check constraints to ensure ratings are between 0 and 10
    add_check_constraint :encounters, "taste_rating BETWEEN 0 AND 10", name: "valid_taste_rating"
    add_check_constraint :encounters, "smell_rating BETWEEN 0 AND 10", name: "valid_smell_rating"
    add_check_constraint :encounters, "texture_rating BETWEEN 0 AND 10", name: "valid_texture_rating"
    add_check_constraint :encounters, "overall_rating BETWEEN 0 AND 10", name: "valid_overall_rating"
    add_check_constraint :encounters, "potency_rating BETWEEN 0 AND 10", name: "valid_potency_rating"
    
    # Ensure THC/CBD percentages are valid
    add_check_constraint :strains, "thc_percentage BETWEEN 0 AND 100", name: "valid_thc_percentage"
    add_check_constraint :strains, "cbd_percentage BETWEEN 0 AND 100", name: "valid_cbd_percentage"
  end
end