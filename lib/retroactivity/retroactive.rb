# frozen_string_literal: true

module Retroactive
  extend ActiveSupport::Concern

  included do
    before_save :_strip_overriden_attributes_from_save!
    after_save :_log_save_and_apply_cache!

    has_many :logged_changes, :as => :loggable, :class_name => "Retroactivity::LoggedChange"

    scope :as_of, (lambda do |time|
      update_hash = {}

      Retroactivity::LoggedChange.for(name).between(time, Time.now).reverse_chronological.each do |logged_change|
        update_hash[logged_change.loggable_id] ||= {}

        logged_change.unapply_to!(update_hash[logged_change.loggable_id], :skip_validation => true)
      end

      attribute_overwrites = column_names.to_h { |column_name| [column_name, {}] }

      update_hash.each do |id, updates|
        updates.each do |attribute, value|
          attribute_overwrites[attribute][id] = value
        end
      end

      select_query = []

      attribute_overwrites.each do |attribute, overwrites|
        if overwrites.present?
          select_query << "CASE"

          overwrites.each do |id, value|
            select_query << " WHEN id = #{_in_sql(id)} THEN #{_in_sql(value)}"
          end

          select_query << " ELSE #{attribute} END AS #{attribute},"
        else
          select_query << "#{attribute},"
        end
      end

      from(select(select_query.join.chomp(",")), table_name)
    end)

    def as_of!(time)
      as_of(time).attributes.each do |attr_name, transformed_value|
        self[attr_name] = transformed_value
      end

      @frozen_at = time
    end

    def as_of(time)
      obj = if time <= _current_time
              self.class.as_of(time).find_by_id(id) || self.class.new
            else
              clone.tap do |cloned|
                logged_changes.between(_current_time, time).chronological.each { |lc| lc.apply_to!(cloned) }
              end
            end

      obj.instance_variable_set(:@frozen_at, time)
      obj
    end

    private

    def self._in_sql(value)
      return "NULL" if value.nil?
      return "'#{value}'" if value.is_a?(String)

      value
    end

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
