module Sidekiq
  module Sqs
    module Client
      extend ActiveSupport::Concern

      module ClassMethods
        def push(item)
          normed = normalize_item(item)
          normed, payload = process_single(item['class'], normed)

          pushed = false
          if normed['at']
            # FIXME - SQS only supports a delay of 15.minutes
            # probably a schedule queue? or keep this in redis??
            pushed = conn.zadd('schedule', normed['at'].to_s, payload)
          else
           pushed = queue_or_create(queue).send_message(payload)
          end if normed
          pushed ? normed['jid'] : nil
        end

        def push_bulk(items)
          normed = normalize_item(items)
          payloads = items['args'].map do |args|
            _, payload = process_single(items['class'], normed.merge('args' => args, 'jid' => SecureRandom.hex(12)))
            payload
          end.compact

          pushed = false
          queue = Sidekiq.sqs.queues.named(normed['queue'])

          payloads.each_slice(10) do |items|
            ## FIXME error handling
            pushed = queue.batch_send( items ) 
          end

          pushed ? payloads.size : nil
        end
      end

      def queue_or_create(queue)
        Sidekiq.sqs.queues.named(queue) || Sidekiq.sqs.queues.create(queue)
      end
    end
  end
end
