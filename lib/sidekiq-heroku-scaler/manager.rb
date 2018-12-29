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
      autoscalable_workers.each(&method(:autoscale_one))
    end

    private

    attr_reader :heroku_client, :strategy, :workers

    def autoscale_one(worker_name)
      formation = heroku_client.formation_for(worker_name)
      return if formation.blank?

      sidekiq_worker = SidekiqHerokuScaler::Worker.new(worker_name, formation)

      process_formation(sidekiq_worker)
    end

    def process_formation(sidekiq_worker)
      if strategy.increase?(sidekiq_worker)
        heroku_client.update_formation(sidekiq_worker.formation_id, sidekiq_worker.quantity + 1)
      elsif strategy.decrease?(sidekiq_worker)
        heroku_client.update_formation(sidekiq_worker.formation_id, sidekiq_worker.quantity - 1)
      end
    end

    def autoscalable_workers
      heroku_client.sidekiq_workers & workers
    end
  end
end
