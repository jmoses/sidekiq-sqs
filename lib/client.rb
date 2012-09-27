module Sidekiq
  module Sqs
    module Client
      extend ActiveSupport::Concern

      module ClassMethods
        def push(item)
          normed = normalize_item(item)
          normed, payload = process_single(item['class'], normed)

          pushed = false
          ## FIX ME
          Sidekiq.redis do |conn|
            if normed['at']
              pushed = conn.zadd('schedule', normed['at'].to_s, payload)
            else
              _, pushed = conn.multi do
                conn.sadd('queues', normed['queue'])
                conn.rpush("queue:#{normed['queue']}", payload)
              end
            end
          end if normed
          pushed ? normed['jid'] : nil
        end

        def self.push_bulk(items)
          normed = normalize_item(items)
          payloads = items['args'].map do |args|
            _, payload = process_single(items['class'], normed.merge('args' => args, 'jid' => SecureRandom.hex(12)))
            payload
          end.compact

          pushed = false
          ## FIXME
          Sidekiq.redis do |conn|
            _, pushed = conn.multi do
              conn.sadd('queues', normed['queue'])
              conn.rpush("queue:#{normed['queue']}", payloads)
            end
          end

          pushed ? payloads.size : nil
        end
      end
    end
  end
end
