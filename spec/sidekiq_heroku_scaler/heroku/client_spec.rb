# frozen_string_literal: true

RSpec.describe SidekiqHerokuScaler::Heroku::Client do
  let(:instance) { described_class.new('app', 'token') }
  let(:formations) do
    [{ 'id' => 'web-id', 'type' => 'web', 'quantity' => 2, 'command' => 'bin/puma' },
     { 'id' => 'worker-id', 'type' => 'worker', 'quantity' => rand(1..9), 'command' => 'bundle exec sidekiq' }]
  end

  before { allow(instance).to receive(:formations).and_return(formations) }

  describe '#formation_for' do
    subject { instance.formation_for(worker_name) }

    let(:worker_name) { :worker }
    let(:formation) do
      SidekiqHerokuScaler::Heroku::Formation.new(id: 'worker-id', quantity: formations.last['quantity'],
                                                 command: 'bundle exec sidekiq')
    end

    it { expect(subject).to eq(formation) }

    context 'without a formation for the worker' do
      let(:worker_name) { :other }

      it { expect(subject).to be_nil }
    end
  end
end
