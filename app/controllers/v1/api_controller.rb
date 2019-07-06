module V1
  class ApiController < ApplicationController
    include ErrorHandling

    def initialize
      @iex_service = IexService.new
    end

    def symbols
      status, result = @iex_service.get_symbols_by_isin(params['isin'])

      if status
        render json: result
      else
        raise ActionController::BadRequest, result
      end
    end

    def historical_data
      raise ActionController::BadRequest, 'you can only specify one of symbol or iex_id' if params.values_at('symbol', 'iex_id').all?
      raise ActionController::BadRequest, 'you have to specify one of symbol or iex_id' if params.values_at('symbol', 'iex_id').none?

      result = @iex_service.get_chart_data(
        params["period"],
        symbol: params["symbol"],
        iex_id: params["iex_id"]
      )

      render json: [result]
    end
  end
end
