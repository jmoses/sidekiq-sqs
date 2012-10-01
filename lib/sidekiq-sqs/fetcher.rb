module Sidekiq
  module Sqs
    module Fetcher
      extend ActiveSupport::Concern

      included do
        remove_method :fetch
        alias_method_chain :initialize, :sqs
      end

      def initialize_with_sqs(mgr, queues, strict)
        initialize_without_sqs(mgr, queues, strict)
        
        # Fix Queue names
        @queues = @queues.map {|queue| queue.gsub(/^queue:/, '') }
        @unique_queues = @queues.uniq
      end

      # TODO Since there's only one fetcher per manager, we run into the issue
      #      where it takes longer to fetch a single job that it does to process,
      #      on average, so that we have waiting workers even if we have jobs in the
      #      queue because, with the HTTP round trip, fetching single messages is too
      #      slow.
      #
      #      We could fetch 10 at a time, but then we have to worry about stuffing them
      #      into a "cache", and pushing them back into SQS if we die or exit. We could,
      #      I guess, just let the "hold" on them expire, and then they would be picked
      #      up again.  I wonder if that would be 'good enough'
      def fetch
        watchdog('Fetcher#fetch died') do
          return if Sidekiq::Fetcher.done?

          begin
            queue = nil
            msg = nil

            ## FIXME
            queues = queues_cmd
            queues.pop # Last entry is TIMEOUT

            msg = queues.inject(nil) do |message, queue|
              next if message

              Sidekiq.sqs.queues.named(queue).receive_message
            end

            if msg
              @mgr.assign!(msg, File.basename(msg.queue.url))
            else
              after(0) { fetch }
            end
          rescue => ex
            logger.error("Error fetching message from queues (#{@queues.join(', ')}): #{ex}")
            logger.error(ex.backtrace.first)
            sleep(self.class::TIMEOUT)
            after(0) { fetch }
          end
        end
      end
    end
  end
end
