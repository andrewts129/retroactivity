module Retroactivity
  class LoggedChangeItem < ActiveRecord::Base
    belongs_to :logged_change, :class_name => "Retroactivity::LoggedChange"
  end
end