module Retroactive
  extend ActiveSupport::Concern

  included do
    after_save :_log_save
    after_initialize { @frozen_at = nil }

    has_many :logged_changes, :as => :loggable, :class_name => "Retroactivity::LoggedChange"

    def as_of!(time)
      if time < _current_time
        logged_changes.after(time).reverse_chronological.each(&:unapply!)
      else
        raise NotImplementedError
      end

      @frozen_at = time
    end

    private

    def _current_time
      @frozen_at || Time.now
    end

    def _log_save
      logged_changes.create!(
        :operation => Retroactivity::LoggedChange::Operation::UPDATE,
        :data => saved_changes,
        :as_of => _current_time
      )
    end
  end
end