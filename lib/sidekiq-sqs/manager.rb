module Sidekiq
  module Sqs
    module Manager
      extend ActiveSupport::Concern

      included do
        remove_method :assign, :dispatch, :stop
        alias_method_chain :initialize, :sqs
      end

      def initialize_with_sqs(options = {})
        initialize_without_sqs(options)

        @fetcher = Sidekiq::Fetcher.pool(args: [current_actor, options[:queues], !!options[:strict]])
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

      def stop(options={})
        watchdog('Manager#stop died') do
          shutdown = options[:shutdown]
          timeout = options[:timeout]

          @done = true
          Sidekiq::Fetcher.done!
          #@fetcher.finalize

          logger.info { "Shutting down #{@ready.size} quiet workers" }
          @ready.each { |x| x.terminate if x.alive? }
          @ready.clear

          logger.debug { "Clearing workers in redis" }
          Sidekiq.redis do |conn|
            workers = conn.smembers('workers')
            workers.each do |name|
              conn.srem('workers', name) if name =~ /:#{process_id}-/
            end
          end

          return after(0) { signal(:shutdown) } if @busy.empty?
          logger.info { "Pausing up to #{timeout} seconds to allow workers to finish..." }
          hard_shutdown_in timeout if shutdown
        end
      end

      private
      def dispatch
        return if stopped?
        # This is a safety check to ensure we haven't leaked
        # processors somehow.
        raise "BUG: No processors, cannot continue!" if @ready.empty? && @busy.empty?
        raise "No ready processor!?" if @ready.empty?

        @fetcher.fetch!
      end
    end
  end
end
