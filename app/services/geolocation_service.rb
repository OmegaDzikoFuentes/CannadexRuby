# app/services/geolocation_service.rb
class GeolocationService
    def self.nearby_encounters(user, radius_miles = 35)
      return Encounter.none unless user.location
      
      Encounter.near_location(user.location.lat, user.location.lon, radius_miles)
               .public_encounters
               .includes(:strain, :user)
    end
    
    def self.nearby_encounters_for_strain(user, strain, radius_miles = 35)
      return Encounter.none unless user.location
      
      Encounter.where(strain: strain)
               .near_location(user.location.lat, user.location.lon, radius_miles)
               .public_encounters
    end
    
    def self.nearby_users(user, radius_miles = 35)
      return User.none unless user.location
      
      User.near_location(user.location.lat, user.location.lon, radius_miles)
          .where.not(id: user.id)
          .where(discoverable_by_location: true, profile_public: true)
    end
  end