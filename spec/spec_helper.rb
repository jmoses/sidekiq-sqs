$: << 'lib'
require 'sidekiq'
require 'sidekiq-sqs'

RSpec.configure do |config|
  config.mock_framework = :mocha
end

