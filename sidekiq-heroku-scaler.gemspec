# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'sidekiq-heroku-scaler/version'

Gem::Specification.new do |spec|
  spec.name          = 'sidekiq-heroku-scaler'
  spec.version       = SidekiqHerokuScaler::VERSION
  spec.authors       = ['Vital Ryabchinskiy']
  spec.email         = ['vital.ryabchinskiy@gmail.com']

  spec.summary       = 'Sidekiq Heroku Scaler'
  spec.description   = 'Tool to scale sidekiq dynos on Heroku'
  spec.homepage      = 'https://github.com/vitalinfo/sidekiq-heroku-scaler'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'rubocop'

  spec.add_dependency 'activesupport', '> 5', '< 8'
  spec.add_dependency 'platform-api', '> 3', '< 4'
  spec.add_dependency 'sidekiq', '> 4', '< 7'
  spec.metadata['rubygems_mfa_required'] = 'true'
end
