module V1
  class ApiController < ApplicationController
    include ErrorHandling

    def initialize
      @iex_service = IexService.new
    end

    def isin
      status, result = @iex_service.get_symbols_by_isin(params['isin'])

      if status
        render json: result.map{ |record| record.serializable_hash(except: [:id, :created_at, :updated_at]) }
      else
        raise ActionController::BadRequest, result
      end
    end

    def chart
      period, symbol, iex_id = params.values_at('period', 'symbol', 'iex_id')

      status, result = @iex_service.get_chart_data(
        period,
        symbol: symbol,
        iex_id: iex_id
      )

      if status
        render json: result.map{ |record| record.serializable_hash(except: [:created_at, :updated_at, :id, :symbol]) }
      else
        raise ActionController::BadRequest, result
      end
    end
  end
end
