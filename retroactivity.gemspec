require_relative "lib/retroactivity/version"

Gem::Specification.new do |gem|
  gem.name          = "retroactivity"
  gem.version       = Retroactivity::VERSION
  gem.authors       = ["Andrew Smith"]
  gem.email         = ["andrew@andrewsmith.io"]

  gem.summary       = "A library enabling ActiveRecord models to be used as retroactive data structures"
  gem.homepage      = "https://github.com/andrewts129/retroactivity"
  gem.license       = "MIT"

  gem.required_ruby_version = Gem::Requirement.new(">= 2.7.0")

  gem.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|gem|features)/}) }
  end
  gem.require_paths = ["lib"]

  gem.add_dependency "activerecord"

  gem.add_development_dependency "rubocop"
  gem.add_development_dependency "rubocop-rake"
  gem.add_development_dependency "rubocop-rspec"
  gem.add_development_dependency "sqlite3"
  gem.add_development_dependency "timecop"
end
