# frozen_string_literal: true

require 'sidekiq'
require 'sidekiq-heroku-scaler/sidekiq_config'

module SidekiqHerokuScaler
  class Worker
    attr_reader :worker_name

    def initialize(worker_name, formation)
      @worker_name = worker_name
      @formation = formation
    end

    def concurrency
      process['concurrency'] || 0
    end

    def formation_id
      formation.id
    end

    def quantity
      formation.quantity
    end

    def jobs_running?
      Sidekiq::Workers.new.any? { |_process_id, _thread_id, work| queues.include?(work['queue']) }
    end

    def latency
      queues.sum { |queue| Sidekiq::Queue.new(queue).latency }
    end

    def queues_size
      queues.sum { |queue| Sidekiq::Queue.new(queue).size }
    end

    def processes
      @processes ||= Sidekiq::ProcessSet.new.select { |process| process.identity.match?(/\A#{worker_name}\./) }
    end

    private

    attr_reader :formation

    def build_process
      command = formation.command.gsub(/.*sidekiq(\s|\z)/, '').split
      sideki_config = SidekiqHerokuScaler::SidekiqConfig.new(command)
      Sidekiq::Process.new(sideki_config.config)
    end

    def queues
      process['queues'] || []
    end

    def process
      @process ||= processes.first || build_process
    end
  end
end
