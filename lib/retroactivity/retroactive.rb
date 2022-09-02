module Retroactive
  extend ActiveSupport::Concern

  included do
    after_save :_log_save

    has_many :logged_changes, :as => :loggable, :class_name => "Retroactivity::LoggedChange"

    def as_of!(time)
      if time <= _current_time
        logged_changes.between(time, _current_time).reverse_chronological.each(&:unapply!)
      else
        logged_changes.between(_current_time, time).chronological.each(&:apply!)
      end

      @frozen_at = time
    end

    private

    def _current_time
      @frozen_at || Time.now
    end

    def _log_save
      logged_changes.create!(
        :data => saved_changes,
        :as_of => _current_time
      )
    end
  end
end