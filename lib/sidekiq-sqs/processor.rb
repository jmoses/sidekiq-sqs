require 'base64'
require 'zlib'

module Sidekiq
  module Sqs
    module Processor
      extend ActiveSupport::Concern

      included do
        remove_method :stats
        alias_method_chain :process, :sqs
      end

      def process_with_sqs(sqs_message, queue)
        begin
          process_without_sqs(Zlib::Inflate.inflate(Base64.decode64(sqs_message.body)), queue).tap do
            sqs_message.delete
          end
        rescue Celluloid::Task::TerminatedError => error
          # If our thread was killed, requeue the job (SURE HOPE IT'S IDEMPOTENT!)
          sqs_message.visibility_timeout = 10 
        rescue => fatal
          # FIXME Maybe we want to requeue here, if there's a non-job related error?
          # If retry = true, requeue here
          sqs_message.delete
        end
      end

      def stats(*args)
        # FIXME this should, like, do stuff
        yield
      end
    end
  end
end
