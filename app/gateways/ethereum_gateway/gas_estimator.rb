# frozen_string_literal: true

class EthereumGateway
  class GasEstimator < AbstractCommand
    Error = Class.new StandardError

    DEFAULT_AMOUNT = 1

    # TODO: returns gas_limit and gas_price

    # contract_addresses is array of coins including nil for native currency
    #
    def call(from_address:,
             to_address:,
             contract_addresses:,
             account_native:,
             gas_limits: {},
             gas_price: nil,
             gas_factor: 1)

      # На боевом откидываем газ по настройкам чтобы гарантировать транзакции

      gas_price ||= (fetch_gas_price * gas_factor).to_i

      contract_addresses = contract_addresses.compact
      raise Error, 'No contract addresses and no account_native' unless contract_addresses.any? || account_native

      estimated_gas = contract_addresses.map do |address|
        if Rails.env.production?
          gas_limits[address] || raise("Unknown gas limit for #{address}")
        else
          data = abi_encode('transfer(address,uint256)', normalize_address(to_address), '0x' + DEFAULT_AMOUNT.to_s(16))
          estimate_gas(from: from_address, to: address, gas_price: gas_price, data: data)
        end
      rescue Ethereum::Client::NoEnoughtAmount
        gas_limits[address] || raise("Unknown gas limit for #{address}")

      rescue Ethereum::Client::ExecutionFailed => e
        Rails.logger.error e
        gas_limits[address] || raise("Unknown gas limit for #{address}")
      end.sum

      if account_native
        estimated_gas += begin
          if Rails.env.production?
            gas_limits[nil] || raise('Unknown gas limit for native}')
          else
            estimate_gas(from: from_address, to: to_address, gas_price: gas_price, value: DEFAULT_AMOUNT)
          end
        rescue Ethereum::Client::NoEnoughtAmount
          gas_limits[nil] || raise('Unknown gas limit for native}')
        rescue Ethereum::Client::ExecutionFailed => e
          Rails.logger.error e
          gas_limits[nil] || raise('Unknown gas limit for native}')
        end
      end

      logger.info("Estimated gas for transaction from #{from_address} to contract addresses #{contract_addresses.join(', ') || :empty} and to_address:#{to_address} with gas_price: #{gas_price} (account_native: #{account_native}) is '#{estimated_gas}' ")

      estimated_gas
    end
  end
end