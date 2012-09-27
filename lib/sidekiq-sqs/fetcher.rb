module Sidekiq
  module Sqs
    module Fetcher
      extend ActiveSupport::Concern

      def initialize(mgr, queues, strict)
        super

        # Fix Queue names
        @queues = @queues.map {|queue| queue.gsub(/^queue:/, '') }
        @unique_queues = @queues.uniq
      end

      def fetch
        watchdog('Fetcher#fetch died') do
          return if Sidekiq::Fetcher.done?

          begin
            queue = nil
            msg = nil

            ## FIXME
            queues = queues_cmd.pop # Last entry is TIMEOUT

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
            logger.error("Error fetching message: #{ex}")
            logger.error(ex.backtrace.first)
            sleep(TIMEOUT)
            after(0) { fetch }
          end
        end
      end
    end
  end
end
