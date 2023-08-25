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

    def process_formation(sidekiq_worker) # rubocop:disable Metrics/AbcSize
      if strategy.increase?(sidekiq_worker)
        start_sidekiq_workers(sidekiq_worker, strategy.safe_quantity(sidekiq_worker.quantity + strategy.inc_count))
      elsif strategy.decrease?(sidekiq_worker)
        stop_sidekiq_workers(sidekiq_worker, strategy.safe_quantity(sidekiq_worker.quantity - strategy.dec_count))
      end
    end

    def start_sidekiq_workers(sidekiq_worker, count)
      heroku_client.update_formation(sidekiq_worker.formation_id, count)
    end

    def stop_sidekiq_workers(sidekiq_worker, count)
      processes = Sidekiq::ProcessSet.new.select do |process|
        process['busy'].zero? &&
          process['quiet'] == 'false' &&
          process['hostname'].match?(/\A#{sidekiq_worker.worker_name}\./)
      end

      processes.first(count).each(&:stop!)
    end
  end
end
