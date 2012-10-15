module Sidekiq
  module Sqs
    class QueueManager
      attr_accessor :manual_queues, :discovered_queues, :initial_queues, :unique_queues, 
        :wildcard_patterns, :queue_map, :strict

      def initialize(queues, strictly_ordered_queues = false)
        self.initial_queues = queues.dup.freeze
        self.strict = strictly_ordered_queues
        initialize!
      end

      def fetch
        msg = queues_list.inject(nil) do |message, queue|
          message || AWS::SQS::Queue.new(queue_map[queue]).receive_message
        end
      end
      
      # Creating the Redis#blpop command takes into account any
      # configured queue weights. By default Redis#blpop returns
      # data from the first queue that has pending elements. We
      # recreate the queue command each time we invoke Redis#blpop
      # to honor weights and avoid queue starvation.
      def queues_list
        # I really have no idea how this works
        return unique_queues.dup if strict

        queues = queues.sample(unique_queues.size).uniq
        queues.concat(unique_queues - queues)
        queues
      end

      def update!
        autodiscover!
        cache!
        update_unique!
      end

      private
      def queue_named(name)
        Sidekiq.sqs.queues.named(name)
      end

      def all_remote_queues
        Sidekiq.sqs.queues.to_a
      end

      def initialize!
        parse_wildcards!
        prune_wildcards!
        update!
      end

      def parse_wildcards!
        self.wildcard_patterns = {}

        initial_queues.select {|q| q =~ /\*/ }.group_by(&:to_s).each do |queue, items|
          wildcard_patterns[queue] = items.size
        end
      end

      def prune_wildcards!
        self.manual_queues = initial_queues.reject {|queue| wildcard_patterns.keys.include?(queue) }
      end

      def autodiscover!
        self.discovered_queues = []

        unfiltered_queues = all_remote_queues

        # This needs to not muck with the "real" queue.
        wildcard_patterns.each do |pattern, weight|
          if matches = unfiltered_queues.select {|q| q.url =~ /#{pattern}/ }
            matches.each do |queue|
              discovered_queues.concat ([File.basename(queue.url)] * weight)
            end
          end
        end
      end

      def update_unique!
        self.unique_queues = (manual_queues + discovered_queues).uniq
      end

      def cache!
        self.queue_map ||= {}

        (manual_queues + discovered_queues).each do |queue|
          self.queue_map[queue] ||= begin
            if q = queue_named(queue)
              q.url
            end
          rescue AWS::SQS::Errors::NonExistentQueue => ex
            nil
          end
        end
      end
    end
  end
end
