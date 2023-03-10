# frozen_string_literal: true

describe API::V2::Account::Beneficiaries, 'GET', type: :request do
  let(:endpoint) { '/api/v2/account/beneficiaries' }

  let(:member) { create(:member, :level_3) }
  let(:token) { jwt_for(member) }

  let(:blockchain_currency) { create(:blockchain_currency) }
  let!(:pending_beneficiaries_for_member) do
    create_list(:beneficiary, 2, member: member, state: :pending, blockchain_currency: blockchain_currency)
  end

  let!(:active_beneficiaries_for_member) do
    create_list(:beneficiary, 3, member: member, state: :active, blockchain_currency: blockchain_currency)
  end

  let!(:archived_beneficiaries_for_member) do
    create_list(:beneficiary, 2, member: member, state: :archived, blockchain_currency: blockchain_currency)
  end

  let!(:other_member_beneficiaries) do
    create_list(:beneficiary, 5, blockchain_currency: blockchain_currency)
  end

  def response_body
    JSON.parse(response.body)
  end

  before do
    Ability.stubs(:user_permissions).returns({ 'member' => { 'read' => ['Beneficiary'], 'update' => ['Beneficiary'],
                                                             'create' => ['Beneficiary'], 'destroy' => ['Beneficiary'] } })
  end

  context 'without JWT' do
    it do
      get endpoint
      expect(response).to have_http_status :unauthorized
    end
  end

  # TODO: Not enough level spec.
  # TODO: Paginate spec.

  context 'without currency and state' do
    it do
      api_get endpoint, token: token
      expect(response).to have_http_status :ok
      total_for_member = pending_beneficiaries_for_member.count + active_beneficiaries_for_member.count
      expect(response_body.size).to eq total_for_member
    end

    context 'pagination' do
      it 'returns paginated result' do
        api_get endpoint, token: token, params: { page: 1, limit: 1 }
        expect(response).to have_http_status :ok
        result = JSON.parse(response.body)
        expect(result.count).to eq 1

        api_get endpoint, token: token, params: { page: 2, limit: 1 }
        expect(response).to have_http_status :ok
        result = JSON.parse(response.body)
        expect(result.count).to eq 1
      end
    end
  end

  context 'non-existing currency' do
    it do
      api_get endpoint, params: { currency: :uah }, token: token
      expect(response).to have_http_status :unprocessable_entity
      expect(response).to include_api_error('account.currency.doesnt_exist')
    end
  end

  context 'existing currency' do
    let!(:btc_beneficiaries_for_member) do
      create_list(:beneficiary, 3, member: member, blockchain_currency: blockchain_currency)
    end

    it do
      api_get endpoint, params: { currency: :btc }, token: token
      expect(response).to have_http_status :ok
      expect(response_body).to be_all { |b| b['currency'] == 'btc' }
    end
  end

  context 'invalid state' do
    it do
      api_get endpoint, params: { state: :invalid }, token: token
      expect(response).to have_http_status :unprocessable_entity
      expect(response).to include_api_error('account.beneficiary.invalid_state')
    end
  end

  context 'existing state' do
    it do
      api_get endpoint, params: { state: :pending }, token: token
      expect(response).to have_http_status :ok
      expect(response_body).to be_all { |b| b['state'] == 'pending' }
    end
  end

  context 'both currency and state' do
    let!(:active_btc_beneficiaries_for_member) do
      create_list(:beneficiary, 3, member: member, state: :active, blockchain_currency: blockchain_currency)
    end

    it do
      api_get endpoint, params: { currency: :btc, state: :active }, token: token
      expect(response).to have_http_status :ok
      expect(response_body).to be_all { |b| b['currency'] == 'btc' && b['state'] == 'active' }
    end
  end

  context 'unauthorized' do
    before do
      Ability.stubs(:user_permissions).returns([])
    end

    let!(:active_btc_beneficiaries_for_member) do
      create_list(:beneficiary, 3, member: member, state: :active, blockchain_currency: blockchain_currency)
    end

    it 'renders unauthorized error' do
      api_get endpoint, params: { currency: :btc, state: :active }, token: token
      expect(response).to have_http_status :forbidden
      expect(response).to include_api_error('user.ability.not_permitted')
    end
  end
end

describe API::V2::Account::Beneficiaries, 'GET /:id', type: :request do
  let(:endpoint) { '/api/v2/account/beneficiaries' }

  let(:member) { create(:member, :level_3) }
  let(:token) { jwt_for(member) }

  def response_body
    JSON.parse(response.body)
  end

  context 'pending beneficiary' do
    let(:endpoint) { "/api/v2/account/beneficiaries/#{pending_beneficiary.id}" }

    let!(:pending_beneficiary) { create(:beneficiary, member: member) }

    it do
      api_get endpoint, token: token
      expect(response).to have_http_status :ok
      expect(response_body['id']).to eq pending_beneficiary.id
    end
  end

  context 'active beneficiary' do
    let(:endpoint) { "/api/v2/account/beneficiaries/#{active_beneficiary.id}" }

    let!(:active_beneficiary) { create(:beneficiary, state: :active, member: member) }

    it do
      api_get endpoint, token: token
      expect(response).to have_http_status :ok
      expect(response_body['id']).to eq active_beneficiary.id
    end
  end

  context 'fiat beneficiary' do
    let(:blockchain_currency) { create(:blockchain_currency, currency: Currency.find('usd')) }
    let!(:fiat_beneficiary) { create(:beneficiary, member: member, blockchain_currency: blockchain_currency) }
    let(:endpoint) { "/api/v2/account/beneficiaries/#{fiat_beneficiary.id}" }

    it do
      api_get endpoint, token: token
      expect(response).to have_http_status :ok
      expect(response_body['id']).to eq fiat_beneficiary.id
      expect(response_body['data']['account_number']).to eq fiat_beneficiary.masked_account_number
    end
  end

  context 'archived beneficiary' do
    let(:endpoint) { "/api/v2/account/beneficiaries/#{archived_beneficiary.id}" }

    let!(:archived_beneficiary) { create(:beneficiary, state: :archived, member: member) }

    it do
      api_get endpoint, token: token
      expect(response).to have_http_status :not_found
    end
  end

  context 'other member beneficiary' do
    let(:endpoint) { "/api/v2/account/beneficiaries/#{pending_beneficiary.id}" }

    let(:member2) { create(:member, :level_3) }

    let!(:pending_beneficiary) { create(:beneficiary, member: member2) }

    it do
      api_get endpoint, token: token
      expect(response).to have_http_status :not_found
    end
  end

  context 'unauthorized' do
    before do
      Ability.stubs(:user_permissions).returns([])
    end

    let(:endpoint) { "/api/v2/account/beneficiaries/#{pending_beneficiary.id}" }

    let(:member2) { create(:member, :level_3) }

    let!(:pending_beneficiary) { create(:beneficiary, member: member2) }

    it 'renders unauthorized error' do
      api_get endpoint, token: token

      expect(response).to have_http_status :forbidden
      expect(response).to include_api_error('user.ability.not_permitted')
    end
  end
end

describe API::V2::Account::Beneficiaries, 'POST', type: :request do
  let(:endpoint) { '/api/v2/account/beneficiaries' }

  let(:member) { create(:member, :level_3) }
  let(:token) { jwt_for(member) }

  let(:address) { Faker::Blockchain::Bitcoin.address }
  let(:blockchain) { find_or_create(:blockchain, 'btc-testnet', key: 'btc-testnet') }
  let(:beneficiary_data) do
    {
      currency: :btc,
      blockchain_id: blockchain.id,
      name: 'Personal Bitcoin wallet',
      description: 'Multisignature Bitcoin Wallet',
      data: { address: address }.to_json
    }
  end

  def response_body
    JSON.parse(response.body)
  end

  context 'without JWT' do
    it do
      post endpoint
      expect(response).to have_http_status :unauthorized
    end
  end

  context 'invalid params' do
    context 'unauthorized' do
      before do
        Ability.stubs(:user_permissions).returns([])
      end

      it 'renders unauthorized error' do
        api_post endpoint, params: beneficiary_data.merge(description: Faker::String.random(120)), token: token
        expect(response).to have_http_status :forbidden
        expect(response).to include_api_error('user.ability.not_permitted')
      end
    end

    context 'missing required params' do
      %i[currency name data].each do |rp|
        context rp do
          it do
            api_post endpoint, params: beneficiary_data.except(rp), token: token
            expect(response).to have_http_status :unprocessable_entity
            expect(response).to include_api_error("account.beneficiary.missing_#{rp}")
          end
        end
      end
    end

    context 'currency doesn\'t exist' do
      it do
        api_post endpoint, params: beneficiary_data.merge(currency: :uah), token: token
        expect(response).to have_http_status :unprocessable_entity
        expect(response).to include_api_error('account.currency.doesnt_exist')
      end
    end

    context 'name is too long' do
      it do
        api_post endpoint, params: beneficiary_data.merge(name: Faker::String.random(65)), token: token
        expect(response).to have_http_status :unprocessable_entity
        expect(response).to include_api_error('account.beneficiary.too_long_name')
      end
    end

    context 'description is too long' do
      it do
        api_post endpoint, params: beneficiary_data.merge(description: Faker::String.random(256)), token: token
        expect(response).to have_http_status :unprocessable_entity
        expect(response).to include_api_error('account.beneficiary.too_long_description')
      end
    end

    context 'data has invalid type' do
      it do
        api_post endpoint, params: beneficiary_data.merge(data: 'data'), token: token
        expect(response).to have_http_status :unprocessable_entity
        expect(response).to include_api_error('account.beneficiary.non_json_data')
      end
    end

    context 'crypto beneficiary' do
      context 'nil address in data' do
        it do
          beneficiary_data[:data] = { address: nil }.to_json
          api_post endpoint, params: beneficiary_data, token: token
          expect(response).to have_http_status :unprocessable_entity
          expect(response).to include_api_error('account.beneficiary.missing_address_in_data')
        end
      end

      context 'invalid address' do
        it do
          beneficiary_data[:data] = { address: 'wrong address' }.to_json
          api_post endpoint, params: beneficiary_data, token: token
          expect(response).to have_http_status :unprocessable_entity
          expect(response).to include_api_error('account.beneficiary.invalid_address')
        end
      end

      context 'data without address' do
        it do
          beneficiary_data[:data] = { memo: :memo }.to_json

          api_post endpoint, params: beneficiary_data, token: token
          expect(response).to have_http_status :unprocessable_entity
          expect(response).to include_api_error('account.beneficiary.missing_address_in_data')
        end
      end

      context 'disabled withdrawal for currency' do
        let(:currency) { Currency.find(:btc) }

        before do
          currency.update(withdrawal_enabled: false)
        end

        it do
          api_post endpoint, params: beneficiary_data, token: token
          expect(response).to have_http_status :unprocessable_entity
          expect(response).to include_api_error('account.currency.withdrawal_disabled')
        end
      end

      context 'duplicated address' do
        context 'same currency' do
          before do
            blockchain = find_or_create(:blockchain, 'btc-testnet', key: 'btc-testnet')
            create(:beneficiary,
                   member: member,
                   blockchain_currency: BlockchainCurrency.find_by!(blockchain_id: blockchain.id, currency_id: beneficiary_data[:currency]),
                   data: { address: address })
          end

          it do
            api_post endpoint, params: beneficiary_data, token: token
            expect(response).to have_http_status :unprocessable_entity
            expect(response).to include_api_error('account.beneficiary.duplicate_address')
          end
        end

        context 'different currencies' do
          let(:eth_address) { Faker::Blockchain::Ethereum.address }
          let(:eth_beneficiary_data) do
            beneficiary_data.merge({ data: { address: eth_address }.to_json })
          end
          let(:blockchain_currency) { find_or_create(:blockchain_currency, blockchain_id: find_or_create(:blockchain, 'eth-rinkeby', key: 'eth-rinkeby').id, currency_id: 'eth') }

          before do
            create(:beneficiary,
                   member: member,
                   blockchain_currency: blockchain_currency,
                   data: { address: eth_address })
          end

          it do
            api_post endpoint, params: beneficiary_data, token: token
            expect(response).to have_http_status :created
          end
        end

        context 'truncates spaces in address' do
          let(:address) { Faker::Blockchain::Bitcoin.address }

          before do
            beneficiary_data[:data] = { address: ' ' + address + ' ' }.to_json
          end

          it do
            api_post endpoint, params: beneficiary_data, token: token
            expect(response).to have_http_status :created

            result = JSON.parse(response.body)
            expect(Beneficiary.find(result['id']).data['address']).to eq(address)
          end
        end
      end

      # TODO: this spec is about destination tag in address, but Bitcoin does not support it
      #
      # context 'destination tag in address' do
      #   before do
      #     beneficiary_data[:data][:address] = Faker::Blockchain::Bitcoin.address + "?dt=4"
      #   end
      #   it do
      #     api_post endpoint, params: beneficiary_data, token: token
      #     expect(response.status).to eq 201

      #     result = JSON.parse(response.body)
      #     expect(Beneficiary.find(result['id']).data['address']).to eq(beneficiary_data[:data][:address])
      #   end
      # end

      # TODO: Test nil full_name in data for both fiat and crypto.
    end

    context 'fiat beneficiary' do
      let(:fiat_beneficiary_data) do
        {
          blockchain_id: Blockchain.find_by!(key: 'dummy').id,
          currency: :usd,
          name: Faker::Bank.name,
          description: Faker::Company.catch_phrase,
          data: generate(:fiat_beneficiary_data)
        }
      end

      context 'nil address in data' do
        it do
          fiat_beneficiary_data[:data].delete(:address)
          api_post endpoint, params: fiat_beneficiary_data, token: token
          expect(response).to have_http_status :created
          expect(response_body['data']['account_number']).not_to eq fiat_beneficiary_data[:data][:account_number]
        end
      end

      context 'nil data' do
        it do
          fiat_beneficiary_data[:data] = nil
          api_post endpoint, params: fiat_beneficiary_data.except(:data), token: token
          expect(response).to have_http_status :unprocessable_entity
          expect(response).to include_api_error('account.beneficiary.empty_data')
        end
      end

      context 'duplicated address' do
        context 'same currency' do
          before do
            blockchain_currency = BlockchainCurrency.find_by!(blockchain: Blockchain.find_by!(key: 'dummy'), currency_id: :usd)
            create(:beneficiary,
                   member: member,
                   blockchain_currency: blockchain_currency,
                   data: fiat_beneficiary_data[:data])
          end

          it do
            api_post endpoint, params: fiat_beneficiary_data, token: token
            expect(response).to have_http_status :created
          end
        end
      end
    end
  end

  context 'valid params' do
    it 'creates beneficiary for member' do
      expect do
        api_post endpoint, params: beneficiary_data, token: token
      end.to change { member.beneficiaries.count }.by(1)
    end

    it 'creates beneficiary with pending state' do
      api_post endpoint, params: beneficiary_data, token: token
      expect(response).to have_http_status :created
      id = response_body['id']
      expect(Beneficiary.find(id).state).to eq 'pending'
    end
  end
end

describe API::V2::Account::Beneficiaries, 'PATCH /activate', type: :request do
  let(:member) { create(:member, :level_3) }
  let(:token) { jwt_for(member) }

  def response_body
    JSON.parse(response.body)
  end

  context 'invalid params' do
    let!(:pending_beneficiary) { create(:beneficiary, member: member) }

    let(:activation_data) do
      { id: pending_beneficiary.id,
        pin: pending_beneficiary.pin }
    end

    context 'unauthorized' do
      before do
        Ability.stubs(:user_permissions).returns([])
      end

      let(:endpoint) do
        "/api/v2/account/beneficiaries/#{pending_beneficiary.id}/activate"
      end

      it 'renders unauthorized error' do
        api_patch endpoint, params: activation_data, token: token
        expect(response).to have_http_status :forbidden
        expect(response).to include_api_error('user.ability.not_permitted')
      end
    end

    context 'id has invalid type' do
      let(:endpoint) do
        '/api/v2/account/beneficiaries/id/activate'
      end

      it do
        api_patch endpoint, params: activation_data.merge(id: :id), token: token
        expect(response).to have_http_status :unprocessable_entity
        expect(response).to include_api_error('account.beneficiary.non_integer_id')
      end
    end

    context 'pin has invalid type' do
      let(:endpoint) do
        "/api/v2/account/beneficiaries/#{pending_beneficiary.id}/activate"
      end

      it do
        api_patch endpoint, params: activation_data.merge(pin: :pin), token: token
        expect(response).to have_http_status :unprocessable_entity
        expect(response).to include_api_error('account.beneficiary.non_integer_pin')
      end
    end
  end

  context 'pending beneficiary' do
    let(:endpoint) do
      "/api/v2/account/beneficiaries/#{pending_beneficiary.id}/activate"
    end

    let(:activation_data) do
      { id: pending_beneficiary.id,
        pin: pending_beneficiary.pin }
    end

    let!(:pending_beneficiary) { create(:beneficiary, member: member) }

    context 'valid pin' do
      it do
        api_patch endpoint, params: activation_data, token: token
        expect(response).to have_http_status :ok
        expect(response_body['id']).to eq pending_beneficiary.id
        expect(response_body['state']).to eq 'active'
      end
    end

    context 'invalid pin' do
      it do
        activation_data[:pin] = activation_data[:pin] + 1
        api_patch endpoint, params: activation_data, token: token
        expect(response).to have_http_status :unprocessable_entity
        expect(response).to include_api_error('account.beneficiary.invalid_pin')
      end
    end
  end

  context 'active beneficiary' do
    let(:endpoint) do
      "/api/v2/account/beneficiaries/#{active_beneficiary.id}/activate"
    end

    let(:activation_data) do
      { id: active_beneficiary.id,
        pin: active_beneficiary.pin }
    end

    let!(:active_beneficiary) { create(:beneficiary, state: :active, member: member) }

    context 'valid pin' do
      it do
        api_patch endpoint, params: activation_data, token: token
        expect(response).to have_http_status :unprocessable_entity
        expect(response).to include_api_error('account.beneficiary.cant_activate')
      end
    end

    context 'invalid pin' do
      it do
        activation_data[:pin] = activation_data[:pin] + 1
        api_patch endpoint, params: activation_data, token: token
        expect(response).to have_http_status :unprocessable_entity
        expect(response).to include_api_error('account.beneficiary.cant_activate')
      end
    end
  end

  context 'archived beneficiary' do
    let(:endpoint) do
      "/api/v2/account/beneficiaries/#{archived_beneficiary.id}/activate"
    end

    let(:activation_data) do
      { id: archived_beneficiary.id,
        pin: archived_beneficiary.pin }
    end

    let!(:archived_beneficiary) { create(:beneficiary, state: :archived, member: member) }

    context 'any pin' do
      it do
        api_patch endpoint, params: activation_data, token: token
        expect(response).to have_http_status :not_found
      end
    end
  end

  context 'other user beneficiary' do
    let(:member2) { create(:member, :level_3) }

    let(:endpoint) do
      "/api/v2/account/beneficiaries/#{pending_beneficiary.id}/activate"
    end

    let(:activation_data) do
      { id: pending_beneficiary.id,
        pin: pending_beneficiary.pin }
    end

    let!(:pending_beneficiary) { create(:beneficiary, member: member2) }

    context 'any pin' do
      it do
        api_patch endpoint, params: activation_data, token: token
        expect(response).to have_http_status :not_found
      end
    end
  end
end

describe API::V2::Account::Beneficiaries, 'PATCH /resend_pin', type: :request do
  let(:member) { create(:member, :level_3) }
  let(:token) { jwt_for(member) }

  def response_body
    JSON.parse(response.body)
  end

  context 'invalid params' do
    let!(:pending_beneficiary) { create(:beneficiary, member: member) }

    let(:resend_data) do
      { id: pending_beneficiary.id }
    end

    context 'id has invalid type' do
      let(:endpoint) do
        '/api/v2/account/beneficiaries/id/resend_pin'
      end

      it do
        api_patch endpoint, params: resend_data.merge(id: :id), token: token
        expect(response).to have_http_status :unprocessable_entity
        expect(response).to include_api_error('account.beneficiary.non_integer_id')
      end
    end

    context 'unauthorized' do
      before do
        Ability.stubs(:user_permissions).returns([])
      end

      let(:endpoint) do
        "/api/v2/account/beneficiaries/#{pending_beneficiary.id}/resend_pin"
      end

      it 'renders unauthorized error' do
        api_patch endpoint, params: resend_data, token: token
        expect(response).to have_http_status :forbidden
        expect(response).to include_api_error('user.ability.not_permitted')
      end
    end
  end

  context 'pending beneficiary' do
    let(:endpoint) do
      "/api/v2/account/beneficiaries/#{pending_beneficiary.id}/resend_pin"
    end

    let(:resend_data) do
      { id: pending_beneficiary.id }
    end

    let!(:pending_beneficiary) { create(:beneficiary, member: member) }

    context '1 minute from last request on create or resend passed' do
      it do
        pending_beneficiary.update(sent_at: 1.minute.ago)
        api_patch endpoint, params: resend_data, token: token
        expect(response).to have_http_status :no_content
      end
    end

    context '1 minute from last request on create or resend not passed' do
      it do
        api_patch endpoint, params: resend_data, token: token
        expect(response).to have_http_status :unprocessable_entity
        expect(response).to include_api_error('account.beneficiary.cant_resend_within_1_minute')
        expect(response_body.include?('sent_at')).to eq true
      end
    end
  end

  context 'active beneficiary' do
    let(:endpoint) do
      "/api/v2/account/beneficiaries/#{active_beneficiary.id}/resend_pin"
    end

    let(:resend_data) do
      { id: active_beneficiary.id }
    end

    let!(:active_beneficiary) { create(:beneficiary, state: :active, member: member) }

    context '1 minute from last request on create or resend passed' do
      it do
        api_patch endpoint, params: resend_data, token: token
        expect(response).to have_http_status :unprocessable_entity
        expect(response).to include_api_error('account.beneficiary.cant_resend')
      end
    end

    context '1 minute from last request on create or resend not passed' do
      it do
        api_patch endpoint, params: resend_data, token: token
        expect(response).to have_http_status :unprocessable_entity
        expect(response).to include_api_error('account.beneficiary.cant_resend')
      end
    end
  end

  context 'archived beneficiary' do
    let(:endpoint) do
      "/api/v2/account/beneficiaries/#{archived_beneficiary.id}/resend_pin"
    end

    let(:resend_data) do
      { id: archived_beneficiary.id }
    end

    let!(:archived_beneficiary) { create(:beneficiary, state: :archived, member: member) }

    it do
      api_patch endpoint, params: resend_data, token: token
      expect(response).to have_http_status :not_found
    end
  end

  context 'other user beneficiary' do
    let(:member2) { create(:member, :level_3) }

    let(:endpoint) do
      "/api/v2/account/beneficiaries/#{pending_beneficiary.id}/resend_pin"
    end

    let(:activation_data) do
      { id: pending_beneficiary.id,
        pin: pending_beneficiary.pin }
    end

    let!(:pending_beneficiary) { create(:beneficiary, member: member2) }

    it do
      api_patch endpoint, params: activation_data, token: token
      expect(response).to have_http_status :not_found
    end
  end
end

describe API::V2::Account::Beneficiaries, 'DELETE /:id', type: :request do
  let(:member) { create(:member, :level_3) }
  let(:token) { jwt_for(member) }

  def response_body
    JSON.parse(response.body)
  end

  context 'invalid params' do
    let!(:pending_beneficiary) { create(:beneficiary, member: member) }

    let(:activation_data) do
      { id: pending_beneficiary.id,
        pin: pending_beneficiary.pin }
    end

    context 'id has invalid type' do
      let(:endpoint) do
        '/api/v2/account/beneficiaries/id'
      end

      it do
        api_delete endpoint, token: token
        expect(response).to have_http_status :unprocessable_entity
        expect(response).to include_api_error('account.beneficiary.non_integer_id')
      end
    end

    context 'unauthorized' do
      before do
        Ability.stubs(:user_permissions).returns([])
      end

      let(:endpoint) do
        "/api/v2/account/beneficiaries/#{pending_beneficiary.id}"
      end

      it 'renders unauthorized error' do
        api_delete endpoint, token: token
        expect(response).to have_http_status :forbidden
        expect(response).to include_api_error('user.ability.not_permitted')
      end
    end
  end

  context 'pending beneficiary' do
    let(:endpoint) do
      "/api/v2/account/beneficiaries/#{pending_beneficiary.id}"
    end

    let!(:pending_beneficiary) { create(:beneficiary, member: member) }

    it do
      api_delete endpoint, token: token
      expect(response).to have_http_status :no_content
      expect(response.body).to be_empty
    end
  end

  context 'active beneficiary' do
    let(:endpoint) do
      "/api/v2/account/beneficiaries/#{active_beneficiary.id}"
    end

    let!(:active_beneficiary) { create(:beneficiary, state: :active, member: member) }

    it do
      api_delete endpoint, token: token
      expect(response).to have_http_status :no_content
      expect(response.body).to be_empty
    end
  end

  context 'archived beneficiary' do
    let(:endpoint) do
      "/api/v2/account/beneficiaries/#{archived_beneficiary.id}"
    end

    let!(:archived_beneficiary) { create(:beneficiary, state: :archived, member: member) }

    it do
      api_delete endpoint, token: token
      expect(response).to have_http_status :not_found
    end
  end

  context 'other user beneficiary' do
    let(:member2) { create(:member, :level_3) }

    let(:endpoint) do
      "/api/v2/account/beneficiaries/#{pending_beneficiary.id}"
    end

    let!(:pending_beneficiary) { create(:beneficiary, member: member2) }

    it do
      api_delete endpoint, token: token
      expect(response).to have_http_status :not_found
    end
  end
end
