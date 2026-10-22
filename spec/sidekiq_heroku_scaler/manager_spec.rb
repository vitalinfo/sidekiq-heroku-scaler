# frozen_string_literal: true

RSpec.describe SidekiqHerokuScaler::Manager do
  let(:instance) do
    described_class.new(heroku_app_name: 'app', heroku_token: 'token', workers: %w[worker], strategy: strategy)
  end
  let(:strategy) { instance_double(SidekiqHerokuScaler::Strategy::Latency) }
  let(:heroku_client) do
    instance_double(SidekiqHerokuScaler::Heroku::Client, sidekiq_workers: %w[worker], formation_for: nil,
                                                         update_formation: nil)
  end

  before { allow(SidekiqHerokuScaler::Heroku::Client).to receive(:new).and_return(heroku_client) }

  describe '#perform' do
    subject { instance.perform }

    context 'without a formation for the worker' do
      it 'leaves the formation alone' do
        subject

        expect(heroku_client).not_to have_received(:update_formation)
      end
    end
  end
end
