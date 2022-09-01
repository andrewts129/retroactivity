module Retroactivity
  class LoggedChange < ActiveRecord::Base
    CannotUnapplyError = Class.new(StandardError)

    module Operation
      ALL = [
        UPDATE = "update".freeze
      ].freeze
    end

    belongs_to :loggable, :polymorphic => true

    scope :after, ->(time) { where("as_of > ?", time) }
    scope :reverse_chronological, -> { order(:as_of => :desc) }

    def unapply!
      data.each do |attr, change|
        previous_value, new_value = change

        raise CannotUnapplyError unless loggable[attr] == new_value

        loggable[attr] = previous_value
      end
    end
  end
end