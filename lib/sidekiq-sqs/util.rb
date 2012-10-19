require 'active_support/inflector'

module Sidekiq
  module Util
    def constantize(string)
      # Try just requiring the files first
      
      begin
        string.constantize
      rescue LoadError => ex
        begin
          require string.split("::").map(&:underscore).join("/")
          string.constantize
        rescue LoadError => ex
          STDERR.puts("Error loading constant: #{string}. #{ex.message}")
          STDERR.puts(ex.backtrace.join("\n"))
          raise ex
        end
      end
    end
  end
end
