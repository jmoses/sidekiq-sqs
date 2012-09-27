module Sidekiq
  module Sqs
    module Processor
      def process(sqs_message, queue)
        begin
          super(sqs_message.body, queue)
        ensure
          # FIXME Maybe we want to requeue here?
          sqs_message.delete
        end
      end
    end
  end
end
