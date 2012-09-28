module Sidekiq
  module Sqs
    module TopLevel
      def self.sqs
        @sqs_connection ||= AWS::SQS.new
      end
    end
  end
end
