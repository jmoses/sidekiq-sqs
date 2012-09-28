module Sidekiq
  module Sqs
    module Worker
      def perform_async_bulk(args)
        client_push_bulk('class' => self, 'args' => args)
      end

      # args should be an array of single job arguments
      def client_push_bulk(args)
        Sidekiq::Client.push_bulk(args)
      end
    end
  end
end
