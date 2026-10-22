# frozen_string_literal: true

require 'platform-api'
require 'sidekiq-heroku-scaler/heroku/formation'

module SidekiqHerokuScaler
  module Heroku
    class Client
      def initialize(heroku_app_name, heroku_token)
        @heroku_app_name = heroku_app_name
        @heroku_token = heroku_token
      end

      def formations
        @formations ||= formation.list(heroku_app_name)
      end

      def formation_for(worker_name)
        formation = formations.detect { |item| item['type'] == worker_name.to_s }
        return if formation.nil?

        SidekiqHerokuScaler::Heroku::Formation.new(id: formation['id'], quantity: formation['quantity'],
                                                   command: formation['command'])
      end

      def sidekiq_workers
        @sidekiq_workers ||= formations.select { |formation| formation['command'].include?('sidekiq') }
                                       .map { |formation| formation['type'] }
      end

      def update_formation(formation_id, quantity)
        formation.update(heroku_app_name, formation_id, quantity: quantity)
      end

      private

      attr_reader :heroku_app_name, :heroku_token

      def client
        @client ||= PlatformAPI.connect_oauth(heroku_token)
      end

      def formation
        @formation ||= PlatformAPI::Formation.new(client)
      end
    end
  end
end
