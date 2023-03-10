# frozen_string_literal: true

module Workers
  module AMQP
    class DepositProcessor < BelomorConsumer
      def process(payload)
        verify_payload!(payload)

        payload.symbolize_keys!
        if payload[:amount] == '0.0'
          Rails.logger.warn { { message: 'Deposit message is skipped. Amount is zero', payload: payload.inspect } }
          return
        end

        owner_id = payload[:owner_id].to_s.split(':')
        if owner_id[0] != 'user'
          Rails.logger.info { { message: 'Deposit message is skipped. It is not user deposit', payload: payload.inspect } }
          return
        end

        blockchain = Blockchain.find_by!(key: payload[:blockchain_key])
        from_address = payload[:from_address]
        from_address = from_address.downcase if blockchain.address_type == 'ethereum'
        txid = payload[:txid]

        member = Member.find_by!(uid: owner_id[1])
        to_address = payload[:to_address]
        to_address = to_address.downcase if blockchain.address_type == 'ethereum'
        amount = payload[:amount].to_d
        txout = payload[:txout]
        currency = Currency.find(payload[:currency])
        block_number = payload[:block_number].to_i
        status = payload[:status]

        deposit = Deposits::Coin.find_or_create_by!(
          blockchain_id: blockchain.id,
          currency_id: currency.id,
          txid: txid,
          txout: txout
        ) do |d|
          d.address = to_address
          d.amount = amount
          d.member = member
          d.from_addresses = [from_address]
          d.block_number = block_number
        end
        deposit.with_lock do
          raise "Amounts different #{deposit.id}" unless amount == deposit.amount

          Rails.logger.info("Found or created suitable deposit #{deposit.id} for txid #{txid}, amount #{amount}")
          accept_deposit(deposit, currency: currency, blockchain: blockchain) if deposit.submitted?

          if deposit.accepted? && status == 'aml_check'
            Rails.logger.info { { message: 'Aml check deposit', deposit_id: deposit.id } }
            deposit.aml_check!
          end

          if (deposit.accepted? || deposit.aml_check?) && status == 'succeed'
            Rails.logger.info { { message: 'Dispatch deposit', deposit_id: deposit.id } }
            deposit.dispatch!
          end
        end
      rescue ActiveRecord::RecordNotFound, IncorrectPayloadError, JWT::DecodeError => e
        report_exception(e, true, payload)
      end

      private

      def accept_deposit(deposit, currency:, blockchain:)
        min_deposit_amount = BlockchainCurrency.find_by!(blockchain: blockchain, currency: currency).min_deposit_amount

        if deposit.amount < min_deposit_amount
          skip_message = "Skipped deposit ##{deposit.id} because of low amount (#{deposit.amount} < #{min_deposit_amount})"
          Rails.logger.warn skip_message
          deposit.skip!
          deposit.add_error skip_message
        else
          Rails.logger.info("Accepting deposit #{deposit.id}")
          deposit.accept!
        end
      end
    end
  end
end
