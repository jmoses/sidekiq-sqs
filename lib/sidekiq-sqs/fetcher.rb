module Sidekiq
  module Sqs
    module Fetcher
      QueueNotDoneError = Class.new(StandardError)

      extend ActiveSupport::Concern

      included do
        remove_method :fetch
        alias_method_chain :initialize, :sqs
      end

      def initialize_with_sqs(mgr, queues, strict)
        initialize_without_sqs(mgr, queues, strict)
        
        # Fix Queue names
        @queues = @queues.map {|queue| Sidekiq::Client.environmental_queue_name queue.gsub(/^queue:/, '') }
        @unique_queues = @queues.uniq
      end

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
              message || fetch_single_message(queue)
            end

            if msg
              @mgr.assign!(msg, File.basename(msg.queue.url))
            else
              after(5) { fetch }
            end
          rescue QueueNotDoneError
            # Just wait
            after(5) { fetch }
          rescue => ex
            logger.error("Error fetching message from queues (#{@queues.join(', ')}): #{ex}")
            logger.error(ex.backtrace.first)
            sleep(self.class::TIMEOUT)
            after(0) { fetch }
          end
        end
      end

      def fetch_single_message(queue)
        queue = Sidekiq.sqs.queues.named(queue)
        message = queue.receive_message

        if @strictly_ordered_queues && message.nil?
          # If messages being processed, raise
          if queue.invisible_messages != 0
            raise QueueNotDoneError
          end
        else
          message
        end
      end
    end
  end
end
