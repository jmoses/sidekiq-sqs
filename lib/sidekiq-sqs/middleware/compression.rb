require 'zlib'
require 'base64'

module Sidekiq
  module Sqs
    module Middleware
      module Compression
        class Client
          def call(worker_class, message, queue)
            message[0..-1] = Base64.encode64(Zlib::Deflate.deflate(message))

            yield
          end
        end

        class Server
          def call(worker_instance, message, queue)
            message.body[0..-1] = Zlib::Inflate.inflate(Base64.decode64(message.body))
          end
        end
      end
    end
  end
end
