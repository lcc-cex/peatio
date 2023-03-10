# frozen_string_literal: true

describe Wallet do
  context 'validations' do
    subject { build(:wallet, :eth_cold) }

    it 'checks valid record' do
      expect(subject).to be_valid
    end

    it 'validates presence of address' do
      subject.address = nil
      expect(subject).not_to be_valid
      expect(subject.errors.full_messages).to eq ['Address can\'t be blank']
    end

    it 'validates presence of name' do
      subject.name = nil
      expect(subject).not_to be_valid
      expect(subject.errors.full_messages).to eq ['Name can\'t be blank']
    end

    it 'validates inclusion of status' do
      subject.status = 'abc'
      expect(subject).not_to be_valid
      expect(subject.errors.full_messages).to eq ['Status is not included in the list']
    end

    it 'validates inclusion of kind' do
      subject.kind = 'abc'
      expect(subject).not_to be_valid
      expect(subject.errors.full_messages).to eq ['Kind is not included in the list']
    end

    it 'validates name uniqueness' do
      subject.name = described_class.first.name
      expect(subject).not_to be_valid
      expect(subject.errors.full_messages).to eq ['Name has already been taken']
    end

    context 'gateway_wallet_kind_support' do
      it 'allows to create hot wallet' do
        AbstractGateway.stubs(:support_wallet_kind?).returns true
        expect do
          subject.kind = 'hot'
          subject.save!
        end.not_to raise_error
      end

      it 'does not allow to create hot wallet' do
        AbstractGateway.any_instance.stubs(:support_wallet_kind?).returns false
        subject.kind = 'deposit'
        expect(subject).not_to be_valid
        expect(subject.errors.full_messages).to eq ["Gateway 'EthereumGateway' can\'t be used as a 'deposit' wallet"]
      end
    end
  end
end
