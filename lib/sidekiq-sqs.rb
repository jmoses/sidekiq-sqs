require "sidekiq-sqs/version"
require 'sidekiq-sqs/manager'
require 'sidekiq-sqs/fetcher'
require 'sidekiq-sqs/client'

# TODO Manager needs a done callback, to delete the message from SQS on success/fail unless
#      we want it to retry

module Sidekiq
  module Sqs
    module_function
    def enable!
      Sidekiq::Manager.send :include, Sidekiq::Sqs::Manager
      Sidekiq::Fetcher.send :include, Sidekiq::Sqs::Fetcher
      Sidekiq::Client.send :include, Sidekiq::Sqs::Client
    end
  end
end

