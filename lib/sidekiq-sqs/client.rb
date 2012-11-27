require 'base64'
require 'zlib'

module Sidekiq
  module Sqs
    module Client
      extend ActiveSupport::Concern

      RETRYABLE_ERRORS = %w(
        AWS.SimpleQueueService.InternalError
        InternalError
        RequestThrottled
        ServiceUnavailable
      )

      class BulkInsertionError < StandardError
        attr_reader :failed

        def initialize(message, failed = [])
          super(message)
          @failed = failed
        end
      end

      class Retryable < StandardError
      end

      included do
        class << self
          remove_method :push
          remove_method :push_bulk

          alias_method_chain :process_single, :sqs
        end
      end

      module ClassMethods
        def clear_queue(queue_name)
          queue = queue_or_create(queue_name)

          while message = queue.receive_message
            message.delete
          end

          queue
        end


        def push(item)
          normed = normalize_item(item)
          normed, payload = process_single(item['class'], normed)

          pushed = false
          if normed['at']
            # FIXME - SQS only supports a delay of 15.minutes
            # probably a schedule queue? or keep this in redis??
            pushed = conn.zadd('schedule', normed['at'].to_s, payload)
          else
            pushed = queue_or_create(normed['queue']).send_message(payload)
          end if normed
          pushed ? normed['jid'] : nil
        end

        MAX_BULK_RETRIES = 5
        def push_bulk(items)
          queue_name, payloads = format_items(items)
          queue = queue_or_create(queue_name)

          failures, can_retry = bulk_send_to_sqs(queue, payloads)

          retries = 0
          begin
            if can_retry.size > 0
              failed, can_retry = bulk_send_to_sqs(queue, can_retry)
              failures.concat failed

              raise Retryable if can_retry.size > 0
            end
          rescue Retryable
            sleep retries ** 2
            retry if (retries += 1) < MAX_BULK_RETRIES
          end

          if failures.size > 0
            raise BulkInsertionError.new("Some messages failed to insert", failed)
          end

          failures.empty? ? payloads.size : nil
        end

        def format_items(items)
          normed = normalize_item(items)
          payloads = items['args'].map do |args|
            _, payload = process_single(items['class'], normed.merge('args' => args, 'jid' => SecureRandom.hex(12)))
            payload
          end.compact

          [normed['queue'], payloads]
        end

        def bulk_send_to_sqs(queue, formatted_items)
          failures = []
          can_retry = []
          formatted_items.each_slice(10) do |items|
            failed, retryable = send_batch_to_sqs(queue, items)

            failures.concat failed
            can_retry.concat retryable
          end

          [failures, can_retry]
        end

        def send_batch_to_sqs(queue, formatted_items)
          failures, retryables = [], []
          
          begin
            queue.batch_send(formatted_items)
          rescue AWS::SQS::Errors::BatchSendError => error
            retryable, failed = error.failures.partition do |failure|
              RETRYABLE_ERRORS.include?(failure[:error_code])
            end

            failures.concat failed
            retryables.concat retryable
          end
          
          [failures, retryables]
        end

        def queue_or_create(queue)
          begin
            Sidekiq.sqs.queues.named(queue.to_s)
          rescue AWS::SQS::Errors::NonExistentQueue
            Sidekiq.sqs.queues.create(queue.to_s)
          end
        end

        def process_single_with_sqs(worker_class, item)
          item, payload = process_single_without_sqs(worker_class, item)

          return item, Base64.encode64(Zlib::Deflate.deflate(payload))
        end
      end
    end
  end
end
