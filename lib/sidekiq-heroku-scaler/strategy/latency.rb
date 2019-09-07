# frozen_string_literal: true

module SidekiqHerokuScaler
  module Strategy
    class Latency
      attr_reader :inc_count, :dec_count

      def initialize(min_dynos_count:, max_dynos_count:,
                     max_latency:, min_latency:,
                     inc_count: nil, dec_count: nil)
        @min_dynos_count = min_dynos_count
        @max_dynos_count = max_dynos_count
        @max_latency = max_latency
        @min_latency = min_latency
        @inc_count = (inc_count || 1).to_i
        @dec_count = (dec_count || 1).to_i
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
