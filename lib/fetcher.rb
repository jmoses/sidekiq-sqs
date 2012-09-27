module Sidekiq
  module Sqs
    module Fetcher
      extend ActiveSupport::Concern

      module InstanceMethods
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
              Sidekiq.redis { |conn| queue, msg = conn.blpop(*queues_cmd) }

              if msg
                ## FIXME - queue name
                @mgr.assign!(msg, queue.gsub(/.*queue:/, ''))
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
end
