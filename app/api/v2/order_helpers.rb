# frozen_string_literal: true

module API
  module V2
    module OrderHelpers
      DESCRIBED_ERRORS_MESSAGES = %w[
        market.account.insufficient_balance
        market.order.insufficient_market_liquidity
        market.order.invalid_volume_or_price
        market.order.open_orders_limit
      ].freeze

      DESCRIBED_SWAP_ORDERS_ERRORS_MESSAGES = %w[
        market.swap_order.invalid_market
        market.swap_order.outdated_price
        market.swap_order.no_currency_price
        market.swap_order.reached_weekly_limit
        market.swap_order.reached_daily_limit
        market.swap_order.reached_order_limit
        market.swap_order.invalid_currency
        market.swap_order.invalid_market_volume
        market.swap_order.invalid_volume_or_price
      ].freeze

      def create_order(attrs)
        market = ::Market.active.find_spot_by_symbol(attrs[:market])
        service = ::OrderServices::CreateOrder.new(member: current_user)
        service_params = attrs.merge(market: market).symbolize_keys

        result = service.perform(**service_params)

        if result.successful?
          result.data
        else
          error_message = result.errors.first

          if DESCRIBED_ERRORS_MESSAGES.include?(error_message.to_s)
            report_api_error(error_message, request)
          else
            report_exception(error_message)
          end

          error!({ errors: [error_message], open_orders_limit: current_user.open_orders_limit }, 422)
        end
      end

      def create_swap_order(attrs)
        from_currency = ::Currency.find(attrs[:from_currency])
        to_currency = ::Currency.find(attrs[:to_currency])
        request_currency = ::Currency.find(attrs[:request_currency])
        service = ::OrderServices::CreateSwapOrder.new(member: current_user)
        service_params = attrs.merge(from_currency: from_currency, to_currency: to_currency, request_currency: request_currency).symbolize_keys

        result = service.perform(**service_params)

        if result.successful?
          result.data
        else
          error_message = result.errors.first

          if DESCRIBED_ERRORS_MESSAGES.include?(error_message.to_s) || DESCRIBED_SWAP_ORDERS_ERRORS_MESSAGES.include?(error_message.to_s)
            report_api_error(error_message, request)
          else
            report_exception(error_message)
          end

          error!({ errors: [error_message] }, 422)
        end
      end

      def order_param
        params[:order_by].downcase == 'asc' ? 'id asc' : 'id desc'
      end
    end
  end
end
