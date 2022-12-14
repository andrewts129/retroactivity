# frozen_string_literal: true

require "bundler/setup"
require "timecop"
require "yaml"

require "retroactivity"

ActiveRecord::Base.establish_connection(YAML.load_file("spec/database.yml"))

unless ActiveRecord::Base.connection.table_exists?("logged_changes")
  require "rake"

  Rake.application.load_rakefile
  Rake::Task["setup"].invoke

  ActiveRecord::Tasks::DatabaseTasks.migrate
end

RSpec.configure do |config|
  config.example_status_persistence_file_path = ".rspec_status"
  config.disable_monkey_patching!

  config.expect_with(:rspec) do |c|
    c.syntax = :expect
  end

  config.around do |example|
    ActiveRecord::Base.transaction do
      example.run
      raise ActiveRecord::Rollback
    end
  end
end

RSpec::Matchers.define_negated_matcher :not_change, :change
