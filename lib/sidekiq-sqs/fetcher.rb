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
        @queues = @queues.map {|queue| queue.gsub(/^queue:/, '') }

        @queue_manager = Sidekiq::Sqs::QueueManager.new(@queues, strict)
      end

      def fetch
        watchdog('Fetcher#fetch died') do
          return if Sidekiq::Fetcher.done?

          begin
            queue = nil
            msg = nil

            msg = @queue_manager.fetch.inject(nil) do |message, queue|
              message || AWS::SQS::Queue.new(queue).receive_message
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

      # TODO - not even tested that it tries to work
      def ok_to_process_queue(queue, max_concurrent) # Granularity: second
        ts = Time.now.to_i
        keyname = "#{queue}:#{ts}"
        current_running = Sidekiq.redis {|r| r.get keyname }
        if current.nil? || current < max_concurrent
          false
        else
          Sidekiq.redis do |r|
            r.multi do
              r.incr keyname, 1
              r.expire keyname, 10
            end
          end
          true
        end
      end
    end
  end
end
