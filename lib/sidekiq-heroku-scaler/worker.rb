# frozen_string_literal: true

require 'sidekiq'

module SidekiqHerokuScaler
  class Worker
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

    def latency
      queues.sum { |queue| Sidekiq::Queue.new(queue).latency }
    end

    def queues_size
      queues.sum { |queue| Sidekiq::Queue.new(queue).size }
    end

    private

    attr_reader :formation, :worker_name

    def queues
      process['queues'] || []
    end

    def process_set
      @process_set ||= Sidekiq::ProcessSet.new
    end

    def process
      process_set.detect { |p| p.identity.match(/\A#{worker_name}\./) } || {}
    end
  end
end
