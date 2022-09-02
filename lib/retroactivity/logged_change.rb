module Retroactivity
  class LoggedChange < ActiveRecord::Base
    CannotApplyError = Class.new(StandardError)

    belongs_to :loggable, :polymorphic => true

    scope :between, ->(start, finish) { where("? < as_of AND as_of <= ?", start, finish) }
    scope :chronological, -> { order(:as_of => :asc) }
    scope :reverse_chronological, -> { order(:as_of => :desc) }

    def apply!
      data.each do |attr, change|
        previous_value, new_value = change

        raise CannotApplyError unless loggable[attr] == previous_value

        loggable[attr] = new_value
      end
    end

    def unapply!
      data.each do |attr, change|
        previous_value, new_value = change

        raise CannotApplyError unless loggable[attr] == new_value

        loggable[attr] = previous_value
      end
    end
  end
end