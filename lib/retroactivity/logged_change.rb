module Retroactivity
  class LoggedChange < ActiveRecord::Base
    module Operation
      ALL = [
        UPDATE = "update".freeze
      ].freeze
    end

    belongs_to :loggable, :polymorphic => true
  end
end