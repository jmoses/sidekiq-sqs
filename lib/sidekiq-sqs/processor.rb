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
          process_without_sqs(Zlib::Inflate.inflate(Base64.decode64(sqs_message.body)), queue)
        ensure
          # FIXME Maybe we want to requeue here, if there's a non-job related error?
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
