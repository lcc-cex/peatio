# frozen_string_literal: true

namespace :balances do
  desc 'Check parallel execution'
  task check: :environment do
    require Rails.root.join('app/serializers/serializers/event_api/order_created')

    concurrency_level = 4

    eth_currency = Currency.find(:eth)
    trst_currency = Currency.find(:trst)
    market = Market.find_by!(symbol: 'trst_eth')
    blockchain = Blockchain.find_by!(key: 'eth-testnet')
    eth_blockchain_currency = BlockchainCurrency.find_by!(blockchain: blockchain, currency: eth_currency)
    trst_blockchain_currency = BlockchainCurrency.find_by!(blockchain: blockchain, currency: trst_currency)

    member = Member.find_or_create_by!(level: 3, role: :member, uid: 'MEMBER', state: :active)
    member_group = MemberGroup.find_or_create_by!(key: member.group)
    member_group.update!(open_orders_limit: concurrency_level)
    member.accounts.find_or_create_by!(currency: trst_currency)
    member.accounts.find_or_create_by!(currency: eth_currency)
    deposits = concurrency_level.times.map { Deposit.new(type: Deposit.name, member: member, blockchain: blockchain, currency: eth_currency, amount: 1000) }
    beneficiary = member.beneficiaries.create!(blockchain_currency: eth_blockchain_currency, name: 'Beneficiary', state: :active, data: { address: Faker::Blockchain::Ethereum.address })
    withdraws = concurrency_level.times.map { Withdraws::Coin.new(beneficiary: beneficiary, amount: 10, member: member, blockchain: blockchain, currency: eth_currency) }

    member2 = Member.find_or_create_by!(level: 3, role: :member, uid: 'MEMBER2', state: :active)
    member2.accounts.find_or_create_by!(currency: trst_currency)
    member2.accounts.find_or_create_by!(currency: eth_currency)
    deposits2 = concurrency_level.times.map { Deposit.new(type: Deposit.name, member: member2, blockchain: blockchain, currency: trst_currency, amount: 1000) }
    beneficiary2 = member2.beneficiaries.create!(blockchain_currency: trst_blockchain_currency, name: 'Beneficiary 2', state: :active, data: { address: Faker::Blockchain::Ethereum.address })
    withdraws2 = concurrency_level.times.map { Withdraws::Coin.new(beneficiary: beneficiary2, amount: 10, member: member2, blockchain: blockchain, currency: trst_currency) }

    ask_create_order_service = OrderServices::CreateOrder.new(member: member2)
    bid_create_order_service = OrderServices::CreateOrder.new(member: member)
    matching = Workers::AMQP::Matching.new
    order_processor = Workers::AMQP::OrderProcessor.new
    trade_executor = Workers::AMQP::TradeExecutor.new

    wait_for_it = true
    threads = concurrency_level.times.map do |i|
      Thread.new do
        Rails.application.executor.wrap do
          true while wait_for_it
          puts "Start ##{i}"

          deposits[i].save!
          deposits[i].accept!
          deposits[i].dispatch!
          deposits2[i].save!
          deposits2[i].accept!
          deposits2[i].dispatch!

          order_ask_result = ask_create_order_service.perform(market: market, side: :sell, ord_type: 'limit', volume: 0.01, price: 10)
          order_bid_result = bid_create_order_service.perform(market: market, side: :buy, ord_type: 'limit', volume: 0.01, price: 10)
          matching.process({ action: 'submit', order: order_ask_result.data.to_matching_attributes }, nil, nil)
          matching.process({ action: 'submit', order: order_bid_result.data.to_matching_attributes }, nil, nil)
          order_processor.process('action' => 'submit', 'order' => { 'id' => order_ask_result.data.id })
          order_processor.process('action' => 'submit', 'order' => { 'id' => order_bid_result.data.id })
          trade_executor.process(
            action: 'execute',
            trade: {
              market_id: market.symbol,
              maker_order_id: order_ask_result.data.id,
              taker_order_id: order_bid_result.data.id,
              strike_price: 10,
              amount: 0.01,
              total: 0.1
            }
          )

          withdraws[i].save!
          withdraws[i].with_lock { withdraws[i].accept! }
          withdraws2[i].save!
          withdraws2[i].with_lock { withdraws2[i].accept! }

          puts "Finish ##{i}"
        end
      end
    end
    wait_for_it = false
    threads.each(&:join)

    %i[eth trst].each do |currency_id|
      locked_deposits_amount = Deposit.where(is_locked: true, currency_id: currency_id).sum(:amount)
      locked_withdraws_sum = Withdraw.where(is_locked: true, currency_id: currency_id).sum(:sum)
      locked_orders_amount = OrderAsk.active.where(ask: currency_id).sum(:locked) + OrderBid.active.where(bid: currency_id).sum(:locked)
      locked_account_amount = Account.where(currency_id: currency_id).sum(:locked)
      puts "Currency: #{currency_id}"
      puts "Locked in deposits: #{locked_deposits_amount}"
      puts "Locked in withdraws: #{locked_withdraws_sum}"
      puts "Locked in orders: #{locked_orders_amount}"
      puts "Locked in accounts: #{locked_account_amount}"
      if locked_account_amount == locked_deposits_amount + locked_withdraws_sum + locked_orders_amount
        puts 'Locked amount in accounts is correct'
      else
        puts 'Locked amount in accounts is INCORRECT'
      end
    end
  ensure
    ActiveRecord::Base.connection_pool.disconnect!
  end
end
