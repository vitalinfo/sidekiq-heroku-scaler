# frozen_string_literal: true

RSpec.describe SidekiqHerokuScaler::Strategy::Latency do
  subject { described_class.new(min_dynos_count: 1, max_dynos_count: max_dynos_count,
                                max_latency: 60, min_latency: 30,
                                inc_count: 2, dec_count: 2) }

  let(:max_dynos_count) { 10 }

  context '#safe_quantity' do
    it 'returns 1 if zero' do
      expect(subject.safe_quantity(0)).to eq 1
    end

    it 'returns 1 if less than zero' do
      expect(subject.safe_quantity(-1)).to eq 1
    end

    it 'returns max if more than max' do
      expect(subject.safe_quantity(max_dynos_count + 1)).to eq max_dynos_count
    end

    context 'returns value if it in range' do
      let(:quantity) { rand(1..max_dynos_count) }

      it do
        expect(subject.safe_quantity(quantity)).to eq quantity
      end

    end
  end
end
