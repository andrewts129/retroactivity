# frozen_string_literal: true

require "active_record"
require "bundler/gem_tasks"
require "fileutils"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

desc "Generate the migrations for database tables needed by retroactivity"
task :setup do
  migration_directory = File.join(File.dirname(__FILE__), ActiveRecord::Migrator.migrations_paths.first)
  FileUtils.mkdir_p(migration_directory)

  migration_path = File.join(migration_directory, "#{Time.now.strftime('%Y%m%d%H%M%S')}_create_logged_changes.rb")
  File.write(migration_path, <<~MIGRATION)
    # frozen_string_literal: true

    class CreateLoggedChanges < ActiveRecord::Migration[7.0]
      def change
        create_table :logged_changes do |t|
          t.references :loggable, :polymorphic => true, :null => false, :index => false
          t.json :data, :null => false
          t.datetime :as_of, :null => false
        end

        add_index :logged_changes, [:loggable_type, :loggable_id, :as_of], :order => { :as_of => :desc }
      end
    end
  MIGRATION
end

task :default => :spec
