# frozen_string_literal: true

module Retroactive
  extend ActiveSupport::Concern

  included do
    before_save :_strip_overriden_attributes_from_save!
    after_save :_log_save_and_apply_cache!

    has_many :logged_changes, :as => :loggable, :class_name => "Retroactivity::LoggedChange"

    def as_of!(time)
      if time <= _current_time
        logged_changes.between(time, _current_time).reverse_chronological.each(&:unapply!)
      else
        logged_changes.between(_current_time, time).chronological.each(&:apply!)
      end

      @frozen_at = time
    end

    def as_of(time)
      clone.tap do |cloned|
        cloned.as_of!(time)
      end
    end

    private

    def _current_time
      @frozen_at || Time.now
    end

    def _strip_overriden_attributes_from_save!
      @attrs_to_apply_post_save = changes_to_save
        .slice(*_attrs_overriden_by_logged_changes)
        .transform_values { |_value_pre_change, value_post_change| value_post_change }

      @attrs_to_apply_post_save.each_key { |attr_name| _undo_pending_change!(attr_name) }
    end

    def _attrs_overriden_by_logged_changes
      return [] if @frozen_at.nil?

      real = Time.now
      raise Retroactivity::CannotMakeFutureDatedUpdatesError if @frozen_at > real

      logged_changes.between(@frozen_at, real).flat_map { |logged_change| logged_change.data.keys }.uniq
    end

    def _undo_pending_change!(attr_name)
      self[attr_name] = attribute_in_database(attr_name)
    end

    def _log_save_and_apply_cache!
      logged_changes.create!(
        :data => saved_changes,
        :as_of => _current_time
      )

      @attrs_to_apply_post_save.each do |attr_name, value|
        self[attr_name] = value
      end

      @attrs_to_apply_post_save = nil
    end
  end
end
