require "bundler/setup"
require "yaml"
require "retroactivity"

ActiveRecord::Base.establish_connection(YAML::load_file("spec/database.yml"))

RSpec.configure do |config|
  config.example_status_persistence_file_path = ".rspec_status"
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
