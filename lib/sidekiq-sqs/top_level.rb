module Sidekiq
  module Sqs
    module TopLevel
      module_function
      def sqs
        @sqs_connection ||= AWS::SQS.new
      end
    end
  end
end
