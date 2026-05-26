# app/models/user_location.rb
class UserLocation < ApplicationRecord
    belongs_to :user
  
    validates :user_id, presence: true, uniqueness: true
  
    scope :near, ->(lat, lng, radius_miles = 35) {
      where(
        "ST_DWithin(coordinates, ST_SetSRID(ST_MakePoint(?, ?), 4326), ?)",
        lng, lat, radius_miles * 1609.34
      )
    }
  
    def set_coordinates(lat, lng)
      self.coordinates = "POINT(#{lng} #{lat})"
      self.located_at  = Time.current
    end
  
    def latitude
      coordinates&.lat
    end
  
    def longitude
      coordinates&.lon
    end
  
    def to_s
      [city, state, country].compact.reject(&:blank?).join(', ')
    end
  end