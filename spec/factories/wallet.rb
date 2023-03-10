# frozen_string_literal: true

FactoryBot.define do
  sequence(:wallet_name) do |n|
    "wallet-name-#{n}"
  end

  factory :wallet do
    name { generate :wallet_name }
    status { 'active' }

    trait :eth_deposit do
      after(:create) do |w|
        CurrencyWallet.create(currency_id: 'eth', wallet_id: w.id)
      end

      association :blockchain, strategy: :find_or_create, key: 'eth-rinkeby'
      name { 'Ethereum Deposit Wallet' }
      address { Faker::Blockchain::Ethereum.address }
      kind               { 'deposit' }
      max_balance        { 0.0 }
    end

    trait :eth_hot do
      after(:create) do |w|
        CurrencyWallet.create(currency_id: 'eth', wallet_id: w.id)
      end

      association :blockchain, strategy: :find_or_create, key: 'eth-rinkeby'
      name { 'Ethereum Hot Wallet' }
      address { Faker::Blockchain::Ethereum.address }
      kind               { 'hot' }
      max_balance        { 100.0 }
    end

    trait :eth_warm do
      after(:create) do |w|
        CurrencyWallet.create(currency_id: 'eth', wallet_id: w.id)
      end

      association :blockchain, strategy: :find_or_create, key: 'eth-rinkeby'
      name { 'Ethereum Warm Wallet' }
      address { Faker::Blockchain::Ethereum.address }
      kind               { 'warm' }
      max_balance        { 1000.0 }
    end

    trait :eth_cold do
      after(:create) do |w|
        CurrencyWallet.create(currency_id: 'eth', wallet_id: w.id)
      end

      association :blockchain, strategy: :find_or_create, key: 'eth-rinkeby'
      name               { 'Ethereum Cold Wallet' }
      address            { '0x2b9fBC10EbAeEc28a8Fc10069C0BC29E45eBEB9C' }
      kind               { 'cold' }
      max_balance        { 1000.0 }
    end

    trait :eth_fee do
      after(:create) do |w|
        CurrencyWallet.create(currency_id: 'eth', wallet_id: w.id)
      end

      association :blockchain, strategy: :find_or_create, key: 'eth-rinkeby'
      use_as_fee_source  { true }
      name               { 'Ethereum Fee Wallet' }
      address            { '0x45a31b15a2ab8a8477375b36b6f5a0c63733dce8' }
      kind               { 'fee' }
      max_balance        { 1000.0 }
    end

    trait :trst_deposit do
      after(:create) do |w|
        CurrencyWallet.create(currency_id: 'trst', wallet_id: w.id)
      end

      association :blockchain, strategy: :find_or_create, key: 'eth-rinkeby'
      name               { 'Trust Coin Deposit Wallet' }
      address            { '0x828058628DF254Ebf252e0b1b5393D1DED91E369' }
      kind               { 'deposit' }
      max_balance        { 0.0 }
    end

    trait :trst_hot do
      after(:create) do |w|
        CurrencyWallet.create(currency_id: 'trst', wallet_id: w.id)
      end

      association :blockchain, strategy: :find_or_create, key: 'eth-rinkeby'
      name               { 'Trust Coin Hot Wallet' }
      address            { '0xb6a61c43DAe37c0890936D720DC42b5CBda990F9' }
      kind               { 'hot' }
      max_balance        { 100.0 }
    end

    trait :btc_deposit do
      after(:create) do |w|
        CurrencyWallet.create(currency_id: 'btc', wallet_id: w.id)
      end

      association :blockchain, strategy: :find_or_create, key: 'btc-testnet'
      name               { 'Bitcoin Deposit Wallet' }
      address            { '3DX3Ak4751ckkoTFbYSY9FEQ6B7mJ4furT' }
      kind               { 'deposit' }
      max_balance        { 0.0 }
    end

    trait :btc_hot do
      after(:create) do |w|
        CurrencyWallet.create(currency_id: 'btc', wallet_id: w.id)
      end

      association :blockchain, strategy: :find_or_create, key: 'btc-testnet'
      name               { 'Bitcoin Hot Wallet' }
      address            { '3NwYr8JxjHG2MBkgdBiHCxStSWDzyjS5U8' }
      kind               { 'hot' }
      max_balance        { 500.0 }
    end

    trait :btc_bz_hot do
      after(:create) do |w|
        create(:currency_wallet, currency_id: 'btc_bz', wallet_id: w.id)
      end

      name               { 'Bitcoin BZ Hot Wallet' }
      address            { '3NwYr8JxjHG2MBkgdBiHCxStSWDzyjS5U8' }
      kind               { 'hot' }
      max_balance        { 500.0 }
    end

    trait :fake_deposit do
      after(:create) do |w|
        CurrencyWallet.create(currency_id: 'fake', wallet_id: w.id)
      end

      association :blockchain, strategy: :find_or_create, key: 'fake-testnet'
      name              { 'Fake Currency Deposit Wallet' }
      address           { 'fake-deposit' }
      kind              { 'deposit' }
      max_balance       { 0.0 }
    end

    trait :fake_hot do
      after(:create) do |w|
        CurrencyWallet.create!(currency_id: 'fake', wallet_id: w.id)
      end

      association :blockchain, strategy: :find_or_create, key: 'fake-testnet'
      name              { 'Fake Currency Hot Wallet' }
      address           { 'fake-hot' }
      kind              { 'hot' }
      max_balance       { 10.0 }
    end

    trait :fake_warm do
      after(:create) do |w|
        CurrencyWallet.create(currency_id: 'fake', wallet_id: w.id)
      end

      association :blockchain, strategy: :find_or_create, key: 'fake-testnet'
      name              { 'Fake Currency Warm Wallet' }
      address           { 'fake-warm' }
      kind              { 'warm' }
      max_balance       { 100.0 }
    end

    trait :fake_cold do
      after(:create) do |w|
        CurrencyWallet.create(currency_id: 'fake', wallet_id: w.id)
      end

      association :blockchain, strategy: :find_or_create, key: 'fake-testnet'
      name              { 'Fake Currency Cold Wallet' }
      address           { 'fake-cold' }
      kind              { 'cold' }
      max_balance       { 1000.0 }
    end

    trait :fake_fee do
      after(:create) do |w|
        CurrencyWallet.create(currency_id: 'fake', wallet_id: w.id)
      end

      use_as_fee_source { true }
      association :blockchain, strategy: :find_or_create, key: 'fake-testnet'
      name               { 'Fake Currency Fee Wallet' }
      address            { 'fake-fee' }
      kind               { 'fee' }
      max_balance        { 1000.0 }
    end

    trait :sol_spl_hot do
      address = 'A4PjS9msRpWRi6RB1jatUpXfXN5k3JaSqJsbW7qNB61N'

      use_as_fee_source { true }
      association :blockchain, factory: [:blockchain, 'sol-testnet'], strategy: :find_or_create, key: 'sol-testnet'
      name               { 'Sol Currency Fee Wallet' }
      address            { address }
      kind               { 'hot' }
      max_balance        { 1000.0 }

      after(:create) do |w|
        CurrencyWallet.create(currency_id: 'sol_spl', wallet_id: w.id)
      end
    end
  end
end
