# frozen_string_literal: true

module SidekiqHerokuScaler
  module Strategy
    class Latency
      def initialize(min_dynos_count:, max_dynos_count:, max_latency:, min_latency:)
        @min_dynos_count = min_dynos_count
        @max_dynos_count = max_dynos_count
        @max_latency = max_latency
        @min_latency = min_latency
      end

      def increase?(sidekiq_worker)
        sidekiq_worker.quantity < max_dynos_count &&
          sidekiq_worker.latency > max_latency &&
          sidekiq_worker.queues_size > sidekiq_worker.quantity * sidekiq_worker.concurrency
      end

      def decrease?(sidekiq_worker)
        sidekiq_worker.latency < min_latency && sidekiq_worker.quantity > min_dynos_count
      end

      private

      attr_reader :min_dynos_count, :max_dynos_count, :max_latency, :min_latency
    end
  end
end
