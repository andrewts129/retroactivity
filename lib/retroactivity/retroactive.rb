module Retroactive
  extend ActiveSupport::Concern

  included do
    after_save :_log_save

    has_many :logged_changes, :as => :loggable, :class_name => "Retroactivity::LoggedChange"

    private

    def _log_save
      logged_changes.create!(
        :operation => Retroactivity::LoggedChange::Operation::UPDATE,
        :data => saved_changes,
        :as_of => Time.now
      )
    end
  end
end