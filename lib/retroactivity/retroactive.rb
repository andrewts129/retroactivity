module Retroactive
  extend ActiveSupport::Concern

  included do
    attr_accessor :logged_changes

    after_save :_log_change

    private

    def _log_change
      (@logged_changes || @logged_changes = []) << saved_changes
    end
  end
end