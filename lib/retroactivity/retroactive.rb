# frozen_string_literal: true

module Retroactive
  extend ActiveSupport::Concern

  included do
    before_save :_strip_overriden_attributes_from_save!
    after_save :_log_save_and_apply_cache!

    has_many :logged_changes, :as => :loggable, :class_name => "Retroactivity::LoggedChange"

    scope :as_of, ->(time) do
      changes_to_apply = 
        select("changes_to_apply.*")
          .from(
            select("logged_changes.loggable_type, logged_changes.loggable_id", "logged_change_items.old_value AS value", "ROW_NUMBER() OVER (PARTITION BY logged_changes.loggable_id ORDER BY logged_changes.as_of ASC) ranked_order")
              .from("logged_changes")
              .joins("logged_change_items")
              .where("logged_changes.as_of > ?", time),
            "changes_to_apply"
          ).where("changes_to_apply.ranked_order = 1")

      puts changes_to_apply.to_sql
      sub_select = nil
      
      from(sub_select, table_name)
    end

    def as_of!(time)
      as_of(time).attributes.each do |attr_name, transformed_value|
        self[attr_name] = transformed_value
      end

      @frozen_at = time
    end

    def as_of(time)
      clone.tap do |cloned|
        if time <= _current_time
          logged_changes.between(time, _current_time).reverse_chronological.each { |lc| lc.unapply_to!(cloned) }
        else
          logged_changes.between(_current_time, time).chronological.each { |lc| lc.apply_to!(cloned) }
        end

        cloned.instance_variable_set(:@frozen_at, time)
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
        :as_of => _current_time,
        :logged_change_items_attributes => saved_changes.map do |column_name, change|
          {
            :column_name => column_name,
            :old_value => change[0],
            :new_value => change[1]
          }
        end
      )

      @attrs_to_apply_post_save.each do |attr_name, value|
        self[attr_name] = value
      end

      @attrs_to_apply_post_save = nil
    end
  end
end
