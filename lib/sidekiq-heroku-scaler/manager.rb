# frozen_string_literal: true

require 'sidekiq-heroku-scaler/heroku/client'
require 'sidekiq-heroku-scaler/worker'

module SidekiqHerokuScaler
  class Manager
    def initialize(heroku_app_name:, heroku_token:, workers:, strategy:)
      @heroku_client = SidekiqHerokuScaler::Heroku::Client.new(heroku_app_name, heroku_token)
      @strategy = strategy
      @workers = workers
    end

    def perform
      autoscalable_workers.each do |worker_name|
        autoscale_one(worker_name)
      end
    end

    private

    attr_reader :heroku_client, :strategy, :workers

    def autoscalable_workers
      heroku_client.sidekiq_workers & workers
    end

    def autoscale_one(worker_name)
      formation = heroku_client.formation_for(worker_name)
      return if formation.blank?

      sidekiq_worker = SidekiqHerokuScaler::Worker.new(worker_name, formation)

      process_formation(sidekiq_worker)
    end

    def decrease_delta_for(sidekiq_worker, delta)
      return delta unless strategy.smart_decrease

      processes = sidekiq_worker.processes.reverse.take_while do |process|
        process['busy'].zero? && process['quiet'] == 'false'
      end

      processes.size < delta.abs ? -processes.size : delta
    end

    def process_formation(sidekiq_worker)
      if strategy.increase?(sidekiq_worker)
        update_formation(sidekiq_worker, strategy.inc_count)
      elsif strategy.decrease?(sidekiq_worker)
        stop_sidekiq_workers(sidekiq_worker, -strategy.dec_count)
      end
    end

    def stop_sidekiq_workers(sidekiq_worker, delta)
      delta = decrease_delta_for(sidekiq_worker, delta)

      update_formation(sidekiq_worker, delta)
    end

    def update_formation(sidekiq_worker, delta)
      heroku_client.update_formation(sidekiq_worker.formation_id,
                                     strategy.safe_quantity(sidekiq_worker.quantity + delta))
    end
  end
end
