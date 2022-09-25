# frozen_string_literal: true

module Retroactive
  extend ActiveSupport::Concern

  included do
    before_save :_strip_overriden_attributes_from_save!
    after_save :_log_save_and_apply_cache!

    has_many :logged_changes, :as => :loggable, :class_name => "Retroactivity::LoggedChange"

    scope :as_of, lambda { |time|
      changes_to_apply =
        select("*").from(
          Retroactivity::LoggedChange
            .joins(:logged_change_items)
            .select("logged_changes.loggable_type, logged_changes.loggable_id", "logged_change_items.column_name", "logged_change_items.old_value AS value", "ROW_NUMBER() OVER (PARTITION BY logged_changes.loggable_id, logged_change_items.column_name ORDER BY logged_changes.as_of ASC) ranked_order")
            .where("logged_changes.as_of > ?", time)
        )
          .where("ranked_order = 1")

      subquery = select(
        column_names.map do |column_name|
          "CASE WHEN (SELECT EXISTS (SELECT 1 FROM (#{changes_to_apply.to_sql}) cta WHERE cta.loggable_type = '#{name}' AND cta.loggable_id = id AND cta.column_name = '#{column_name}')) THEN (SELECT json_extract(cta.value, '$') FROM (#{changes_to_apply.to_sql}) cta WHERE cta.loggable_type = '#{name}' AND cta.loggable_id = id AND cta.column_name = '#{column_name}' LIMIT 1) ELSE #{column_name} END AS #{column_name}"
        end
      )

      from(subquery, table_name)
    }

    def as_of!(time)
      as_of(time).attributes.each do |attr_name, transformed_value|
        self[attr_name] = transformed_value
      end
    end

    def as_of(time)
      self.class.as_of(time).find_by(:id => id) || self.class.new
    end

    private

    def _current_time
      return Time.now unless changed?

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

      logged_changes.between(@frozen_at, real).flat_map { |logged_change| logged_change.logged_change_items.map(&:column_name) }.uniq
    end

    def _undo_pending_change!(attr_name)
      self[attr_name] = attribute_in_database(attr_name)
    end

    def _log_save_and_apply_cache!
      logged_changes.create!(
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
