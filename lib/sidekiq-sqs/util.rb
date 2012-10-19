module Sidekiq
  module Sqs
    module Util
      extend ActiveSupport::Concern

      included do
        remove_method :constantize
      end

      def constantize(string)
        string.constantize
      end
    end
  end
end
