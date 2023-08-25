# frozen_string_literal: true

module SidekiqHerokuScaler
  module Strategy
    class Latency
      attr_reader :inc_count, :dec_count

      # rubocop:disable Metrics/ParameterLists
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
      # rubocop:enable Metrics/ParameterLists

      def increase?(sidekiq_worker)
        sidekiq_worker.quantity < max_dynos_count &&
          (sidekiq_worker.latency > max_latency ||
            (sidekiq_worker.quantity.zero? && sidekiq_worker.latency.positive?))
      end

      def decrease?(sidekiq_worker)
        sidekiq_worker.quantity > min_dynos_count &&
          sidekiq_worker.latency < min_latency &&
          (sidekiq_worker.quantity > 1 || !sidekiq_worker.jobs_running?) &&
          (!sidekiq_worker.jobs_running? || safe_quantity(sidekiq_worker.quantity - dec_count).positive?)
      end

      def safe_quantity(quantity)
        return min_dynos_count if quantity < min_dynos_count

        [quantity, max_dynos_count].min
      end

      private

      attr_reader :min_dynos_count, :max_dynos_count, :max_latency, :min_latency
    end
  end
end
