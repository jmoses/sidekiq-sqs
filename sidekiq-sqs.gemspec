# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'sidekiq-sqs/version'

Gem::Specification.new do |gem|
  gem.name          = "sidekiq-sqs"
  gem.version       = Sidekiq::Sqs::VERSION
  gem.authors       = ["Jon Moses"]
  gem.email         = ["jon@burningbush.us"]
  gem.description   = %q{SQS backed job store for Sidekiq. Redis is still used for stats/job worker tracking}
  gem.summary       = %q{SQS backed job store for Sidekiq}
  gem.homepage      = "http://github.com/jmoses/sidekiq-sqs"

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]

  gem.add_dependency 'activesupport', '> 3.0.0'
  gem.add_dependency 'sidekiq', '~> 2.3.2'
  gem.add_dependency 'aws-sdk', '~> 1.6.6'

  gem.add_development_dependency 'rspec'
  gem.add_development_dependency 'guard'
  gem.add_development_dependency 'guard-rspec'
end
