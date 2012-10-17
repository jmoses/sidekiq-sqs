module Sidekiq
  module Sqs
    module AwsSdk
      module BatchSendFailurePatch
        extend ActiveSupport::Concern

        included do
          remove_method :batch_failures
        end

        def batch_failures entries, response
          response[:failed].inject([]) do |failures, failure|

            entry = entries.find{|e| e[:id] == failure[:id] }

            details = {
              :error_code => failure[:code],
              :error_message => failure[:message],
              :sender_fault => failure[:sender_fault],
              :message => entry[:message_body] # We need this for retrying
            }

            if handle = entry[:receipt_handle]
              details[:receipt_handle] = handle
            end

            failures << details
          end
        end

      end
    end
  end
end
