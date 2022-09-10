# frozen_string_literal: true

module Retroactivity
  class LoggedChange < ActiveRecord::Base
    CannotApplyError = Class.new(StandardError)

    belongs_to :loggable, :polymorphic => true

    scope :between, ->(start, finish) { where("? < as_of AND as_of <= ?", start, finish) }
    scope :chronological, -> { order(:as_of => :asc) }
    scope :reverse_chronological, -> { order(:as_of => :desc) }

    def apply_to!(obj)
      data.each do |attr, change|
        previous_value, new_value = change

        raise CannotApplyError unless obj[attr] == previous_value

        obj[attr] = new_value
      end
    end

    def unapply_to!(obj)
      data.each do |attr, change|
        previous_value, new_value = change

        raise CannotApplyError unless obj[attr] == new_value

        obj[attr] = previous_value
      end
    end
  end
end
