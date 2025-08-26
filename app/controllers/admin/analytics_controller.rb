# app/controllers/admin/analytics_controller.rb
class Admin::AnalyticsController < Admin::ApplicationController
    def dashboard
      stats = {
        users: user_analytics,
        strains: strain_analytics,
        encounters: encounter_analytics,
        battles: battle_analytics,
        recent_activity: recent_activity
      }
      
      render json: { analytics: stats }
    end
    
    def users
      render json: { user_analytics: detailed_user_analytics }
    end
    
    def strains
      render json: { strain_analytics: detailed_strain_analytics }
    end
    
    private
    
    def user_analytics
      {
        total: User.count,
        verified: User.where(age_verified: true).count,
        active_30_days: User.joins(:encounters).where(encounters: { created_at: 30.days.ago..Time.current }).distinct.count,
        new_this_month: User.where(created_at: 1.month.ago..Time.current).count,
        average_level: User.average(:level).round(2),
        top_users_by_encounters: User.order(total_encounters: :desc).limit(10).map { |u| 
          { username: u.username, encounters: u.total_encounters }
        }
      }
    end
    
    def strain_analytics
      {
        total: Strain.count,
        verified: Strain.where(verified: true).count,
        user_contributed: Strain.where(data_source: 'user_contributed').count,
        with_encounters: Strain.where('encounters_count > 0').count,
        average_rating: Strain.where('encounters_count > 0').average(:average_overall_rating).round(2),
        top_strains: Strain.order(encounters_count: :desc).limit(10).map { |s|
          { name: s.name, encounters: s.encounters_count, rating: s.average_overall_rating }
        }
      }
    end
    
    def encounter_analytics
      {
        total: Encounter.count,
        this_month: Encounter.where(created_at: 1.month.ago..Time.current).count,
        public: Encounter.where(public: true).count,
        with_photos: Encounter.joins(:photos_attachments).distinct.count,
        average_rating: Encounter.average(:overall_rating).round(2),
        encounters_by_day: encounters_by_day
      }
    end
    
    def battle_analytics
      {
        total: Battle.count,
        completed: Battle.where(status: 'completed').count,
        active: Battle.where(status: 'active').count,
        pending: Battle.where(status: 'pending').count,
        this_month: Battle.where(created_at: 1.month.ago..Time.current).count
      }
    end
    
    def recent_activity
      activities = Activity.includes(:user, :trackable)
                          .order(created_at: :desc)
                          .limit(20)
      
      activities.map do |activity|
        {
          id: activity.id,
          user: activity.user.username,
          type: activity.activity_type,
          message: activity.formatted_message,
          created_at: activity.created_at
        }
      end
    end
    
    def encounters_by_day
      Encounter.where(created_at: 30.days.ago..Time.current)
               .group_by_day(:created_at)
               .count
               .map { |date, count| { date: date, count: count } }
    end
    
    def detailed_user_analytics
      user_analytics.merge({
        retention: {
          week_1: retention_rate(1.week),
          month_1: retention_rate(1.month),
          month_3: retention_rate(3.months)
        },
        demographics: user_demographics,
        engagement: user_engagement_stats
      })
    end
    
    def detailed_strain_analytics
      strain_analytics.merge({
        categories: category_distribution,
        genetics: genetics_distribution,
        rating_distribution: rating_distribution
      })
    end
    
    def retention_rate(period)
      cohort_users = User.where(created_at: period.ago..(period.ago + 1.day))
      active_users = cohort_users.joins(:encounters)
                                .where(encounters: { created_at: Time.current - 1.week..Time.current })
                                .distinct
      
      return 0 if cohort_users.count.zero?
      (active_users.count.to_f / cohort_users.count * 100).round(2)
    end
    
    def user_demographics
      {
        by_state: User.where.not(state: nil).group(:state).count.sort_by { |k, v| -v }.first(10).to_h,
        by_level: User.group(:level).count
      }
    end
    
    def user_engagement_stats
      {
        average_encounters_per_user: User.where('total_encounters > 0').average(:total_encounters).round(2),
        users_with_battles: User.where('battles_won > 0 OR battles_lost > 0').count,
        users_with_friends: User.joins(:friends).distinct.count
      }
    end
    
    def category_distribution
      Category.joins(:strains).group('categories.name').count
    end
    
    def genetics_distribution
      Strain.where.not(genetics: nil)
            .group(:genetics)
            .count
            .sort_by { |k, v| -v }
            .first(10)
            .to_h
    end
    
    def rating_distribution
      {
        excellent: Strain.where('average_overall_rating >= 9').count,
        very_good: Strain.where('average_overall_rating >= 8 AND average_overall_rating < 9').count,
        good: Strain.where('average_overall_rating >= 7 AND average_overall_rating < 8').count,
        average: Strain.where('average_overall_rating >= 6 AND average_overall_rating < 7').count,
        below_average: Strain.where('average_overall_rating < 6').count
      }
    end
  end
  