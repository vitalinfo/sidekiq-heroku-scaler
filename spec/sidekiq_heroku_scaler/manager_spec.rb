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

    context 'when scaling down with smart decrease' do
      let(:formation) { SidekiqHerokuScaler::Heroku::Formation.new(id: 'formation', quantity: 3, command: 'sidekiq') }
      let(:dec_count) { 2 }
      let(:busy_dynos) { [] }
      let(:processes) do
        (1..3).flat_map do |dyno|
          (1..8).map do |pid|
            Sidekiq::Process.new('identity' => "worker.#{dyno}:#{pid}", 'hostname' => "worker.#{dyno}",
                                 'busy' => busy_dynos.include?(dyno) && pid == 1 ? 1 : 0, 'quiet' => 'false')
          end
        end
      end

      before do
        allow(heroku_client).to receive(:formation_for).and_return(formation)
        allow(Sidekiq::ProcessSet).to receive(:new).and_return(processes)
        allow(strategy).to receive_messages(increase?: false, decrease?: true, dec_count: dec_count,
                                            smart_decrease: true)
        allow(strategy).to receive(:safe_quantity) { |quantity| quantity }
      end

      it 'removes as many dynos as requested when they are all idle' do
        subject

        expect(heroku_client).to have_received(:update_formation).with('formation', 1)
      end

      context 'when only the last dyno is fully idle' do
        let(:busy_dynos) { [2] }

        it 'keeps the dyno with a busy process' do
          subject

          expect(heroku_client).to have_received(:update_formation).with('formation', 2)
        end
      end

      context 'when the last dyno has one busy process among idle ones' do
        let(:dec_count) { 1 }
        let(:busy_dynos) { [3] }

        it 'keeps every dyno' do
          subject

          expect(heroku_client).to have_received(:update_formation).with('formation', 3)
        end
      end

      context 'with ten or more dynos' do
        let(:formation) do
          SidekiqHerokuScaler::Heroku::Formation.new(id: 'formation', quantity: 10, command: 'sidekiq')
        end
        let(:dec_count) { 1 }
        # Sidekiq::ProcessSet sorts by identity, so worker.10 comes before worker.9.
        let(:processes) do
          [10, 9].map do |dyno|
            Sidekiq::Process.new('identity' => "worker.#{dyno}:1", 'hostname' => "worker.#{dyno}",
                                 'busy' => dyno == 10 ? 1 : 0, 'quiet' => 'false')
          end
        end

        it 'checks the highest-numbered dyno, the one Heroku removes' do
          subject

          expect(heroku_client).to have_received(:update_formation).with('formation', 10)
        end
      end
    end
  end
end
