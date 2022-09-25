# frozen_string_literal: true

module Retroactivity
  class LoggedChange < ActiveRecord::Base
    CannotApplyError = Class.new(StandardError)

    belongs_to :loggable, :polymorphic => true
    has_many :logged_change_items, :class_name => "Retroactivity::LoggedChangeItem"

    accepts_nested_attributes_for :logged_change_items

    scope :between, ->(start, finish) { where("? < as_of AND as_of <= ?", start, finish) }
  end
end
