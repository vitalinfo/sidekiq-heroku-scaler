# frozen_string_literal: true

RSpec.describe SidekiqHerokuScaler::Strategy::Latency do
  subject do
    described_class.new(min_dynos_count: min_dynos_count, max_dynos_count: max_dynos_count,
                        max_latency: 60, min_latency: 30,
                        inc_count: inc_count, dec_count: dec_count)
  end

  let(:max_dynos_count) { 10 }
  let(:inc_count) { 2 }
  let(:dec_count) { 2 }

  describe '#safe_quantity' do
    0.upto(1) do |count|
      describe "when min_dynos_count is #{count}" do
        let(:min_dynos_count) { count }

        it 'returns 1 if zero' do
          expect(subject.safe_quantity(0)).to eq(count)
        end

        it 'returns 1 if less than zero' do
          expect(subject.safe_quantity(-1)).to eq(count)
        end

        it 'returns max if more than max' do
          expect(subject.safe_quantity(max_dynos_count + 1)).to eq(max_dynos_count)
        end

        context 'when value in range' do
          let(:quantity) { rand(1..max_dynos_count) }

          it do
            expect(subject.safe_quantity(quantity)).to eq(quantity)
          end
        end
      end
    end
  end

  describe '#decrease?' do
    context 'when min_dynos_count is zero' do
      let(:max_dynos_count) { 2 }
      let(:min_dynos_count) { 0 }

      context 'when quantity equal to dec_count and has only a processing jobs' do
        let(:sidekiq_worker) do
          instance_double(SidekiqHerokuScaler::Worker, quantity: dec_count, latency: 0, jobs_running?: true)
        end

        it { expect(subject).not_to be_decrease(sidekiq_worker) }
      end

      context 'when quantity bigger than dec_count and has only a processing jobs' do
        let(:sidekiq_worker) do
          instance_double(SidekiqHerokuScaler::Worker, quantity: dec_count + 1, latency: 0, jobs_running?: true)
        end
        let(:dec_count) { 1 }

        it { expect(subject).to be_decrease(sidekiq_worker) }
      end
    end

    context 'with a cooldown' do
      subject do
        described_class.new(min_dynos_count: 1, max_dynos_count: max_dynos_count,
                            max_latency: 60, min_latency: 30, cooldown: cooldown)
      end

      let(:cooldown) { rand(300..900) }
      let(:sidekiq_worker) do
        instance_double(SidekiqHerokuScaler::Worker, quantity: 2, latency: 0, jobs_running?: false,
                                                     processes: processes)
      end

      context 'when every process started before the cooldown' do
        let(:processes) { [{ 'started_at' => Time.now.to_f - cooldown - rand(1..60) }] }

        it { expect(subject).to be_decrease(sidekiq_worker) }
      end

      context 'when a process started within the cooldown' do
        let(:processes) do
          [{ 'started_at' => Time.now.to_f - cooldown - rand(1..60) },
           { 'started_at' => Time.now.to_f - cooldown + rand(1..60) }]
        end

        it { expect(subject).not_to be_decrease(sidekiq_worker) }
      end
    end

    pending 'add more'
  end

  describe '#increase?' do
    let(:min_dynos_count) { 1 }
    let(:quantity) { rand(1...max_dynos_count) }
    let(:latency) { rand(0..60) }
    let(:queues_size) { rand(0..max_queue_size) }
    let(:max_queue_size) { rand(1_000..5_000) }
    let(:sidekiq_worker) do
      instance_double(SidekiqHerokuScaler::Worker, quantity: quantity, latency: latency, queues_size: queues_size)
    end

    it { expect(subject).not_to be_increase(sidekiq_worker) }

    context 'with latency above the maximum' do
      let(:latency) { rand(61..120) }

      it { expect(subject).to be_increase(sidekiq_worker) }
    end

    context 'with a maximum queue size' do
      subject do
        described_class.new(min_dynos_count: min_dynos_count, max_dynos_count: max_dynos_count,
                            max_latency: 60, min_latency: 30, max_queue_size: max_queue_size)
      end

      it { expect(subject).not_to be_increase(sidekiq_worker) }

      context 'when more jobs are waiting than the maximum queue size' do
        let(:queues_size) { max_queue_size + rand(1..100) }

        it { expect(subject).to be_increase(sidekiq_worker) }

        context 'with the maximum number of dynos running' do
          let(:quantity) { max_dynos_count }

          it { expect(subject).not_to be_increase(sidekiq_worker) }
        end
      end
    end

    context 'without a maximum queue size' do
      let(:queues_size) { max_queue_size + rand(1..100) }

      it { expect(subject).not_to be_increase(sidekiq_worker) }
    end
  end
end
