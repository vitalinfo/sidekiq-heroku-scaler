# frozen_string_literal: true

module SidekiqHerokuScaler
  module Strategy
    class Latency
      attr_reader :inc_count, :dec_count, :smart_decrease

      def initialize(min_dynos_count:, max_dynos_count:, # rubocop:disable Metrics/ParameterLists
                     max_latency:, min_latency:,
                     inc_count: nil, dec_count: nil,
                     smart_decrease: false,
                     max_queue_size: nil, cooldown: nil)
        @min_dynos_count = min_dynos_count
        @max_dynos_count = max_dynos_count
        @max_latency = max_latency
        @min_latency = min_latency
        @inc_count = (inc_count || 1).to_i
        @dec_count = (dec_count || 1).to_i
        @smart_decrease = smart_decrease
        @max_queue_size = max_queue_size.to_i
        @cooldown = cooldown.to_i
      end

      def increase?(sidekiq_worker)
        sidekiq_worker.quantity < max_dynos_count &&
          (sidekiq_worker.latency > max_latency ||
            (sidekiq_worker.quantity.zero? && sidekiq_worker.latency.positive?) ||
            queue_overflow?(sidekiq_worker))
      end

      def decrease?(sidekiq_worker)
        sidekiq_worker.quantity > min_dynos_count &&
          sidekiq_worker.latency < min_latency &&
          stoppable?(sidekiq_worker) &&
          !cooling_down?(sidekiq_worker)
      end

      def safe_quantity(quantity)
        return min_dynos_count if quantity < min_dynos_count

        [quantity, max_dynos_count].min
      end

      private

      attr_reader :min_dynos_count, :max_dynos_count, :max_latency, :min_latency, :max_queue_size, :cooldown

      # Keeps a freshly started dyno for the next burst instead of dropping it the moment the queue empties.
      def cooling_down?(sidekiq_worker)
        return false unless cooldown.positive?

        sidekiq_worker.processes.any? { |process| Time.now.to_f - process['started_at'].to_f < cooldown }
      end

      # A burst enqueues many jobs at once: the queue size shows it immediately,
      # while latency only crosses the threshold once the oldest job has waited that long.
      def queue_overflow?(sidekiq_worker)
        max_queue_size.positive? && sidekiq_worker.queues_size > max_queue_size
      end

      def stoppable?(sidekiq_worker)
        (sidekiq_worker.quantity > 1 || !sidekiq_worker.jobs_running?) &&
          (!sidekiq_worker.jobs_running? || safe_quantity(sidekiq_worker.quantity - dec_count).positive?)
      end
    end
  end
end
