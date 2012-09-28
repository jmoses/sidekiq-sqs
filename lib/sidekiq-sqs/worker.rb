module Sidekiq
  module Sqs
    module Worker
      def perform_async_bulk(args)
        bulk_arguments = args.map do |single|
          {'class' => self, 'args' => 'single'}
        end

        client_push_bulk(bulk_arguments)
      end

      # args should be an array of single job arguments
      def client_push_bulk(args)
        Sidekiq::Client.push_bulk(args)
      end
    end
  end
end
