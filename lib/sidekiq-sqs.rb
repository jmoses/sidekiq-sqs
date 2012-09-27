require 'active_support'

require "sidekiq-sqs/version"
require 'sidekiq-sqs/manager'
require 'sidekiq-sqs/fetcher'
require 'sidekiq-sqs/client'
require 'sidekiq-sqs/top_level'
require 'sidekiq-sqs/processor'
require 'sidekiq-sqs/middleware/compression'

# TODO The retry server middleware directly writes to a retry zset.
# TODO Need a queue-prefix option to support multiple rails envs

module Sidekiq
  module Sqs
    module_function
    def enable!
      require 'sidekiq/manager'
      require 'sidekiq/fetch'
      require 'sidekiq/client'
      require 'sidekiq/processor'

      Sidekiq::Manager.send :include, Sidekiq::Sqs::Manager
      Sidekiq::Fetcher.send :include, Sidekiq::Sqs::Fetcher
      Sidekiq::Client.send :include, Sidekiq::Sqs::Client
      Sidekiq::Processor.send :include, Sidekiq::Sqs::Processor
      Sidekiq.send :extend, Sidekiq::Sqs::TopLevel

      Sidekiq.configure_client do |config|
        config.client_middleware do |chain|
          chain.add Sidekiq::Sqs::Middleware::Compression::Client
        end
      end

      Sidekiq.configure_server do |config|
        config.server_middleware do |chain|
          chain.remove Sidekiq::Middleware::Server::RetryJobs
          chain.remove Sidekiq::Middleware::Server::Timeout

          chain.add Sidekiq::Sqs::Middleware::Compression::Server
        end
      end
    end
  end
end

