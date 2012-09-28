module Sidekiq
  module Sqs
    module Manager
      extend ActiveSupport::Concern

      included do
        remove_method :assign
      end

      def assign(msg, queue)
        watchdog("Manager#assign died") do
          if stopped?
            # Race condition between Manager#stop if Fetcher
            # is blocked on redis and gets a message after
            # all the ready Processors have been stopped.
            # Push the message back to redis.
            #
            msg.visibility_timeout = 0
          else
            processor = @ready.pop
            @in_progress[processor.object_id] = [msg, queue]
            @busy << processor
            processor.process!(msg, queue)
          end
        end
      end
    end
  end
end
