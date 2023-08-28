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
        let(:sidekiq_worker) { OpenStruct.new(quantity: dec_count, latency: 0, jobs_running?: true) }

        it { expect(subject).not_to be_decrease(sidekiq_worker) }
      end

      context 'when quantity bigger than dec_count and has only a processing jobs' do
        let(:sidekiq_worker) { OpenStruct.new(quantity: dec_count + 1, latency: 0, jobs_running?: true) }
        let(:dec_count) { 1 }

        it { expect(subject).to be_decrease(sidekiq_worker) }
      end
    end

    pending 'add more'
  end
end
