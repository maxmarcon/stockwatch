module V1
  class ApiController < ApplicationController
    include ErrorHandling

    def initialize
      @iex_service = IexService.new
    end

    def isin
      status, result = @iex_service.get_symbols_by_isin(params['isin'])

      if status
        if result.any?
          render json: result.map{ |record| record.serializable_hash(except: [:id, :created_at, :updated_at]) }
        else
          raise ActiveRecord::RecordNotFound, "not_found"
        end
      else
        raise ActionController::BadRequest, result
      end
    end

    def chart
      period, symbol, iex_id = params.values_at('period', 'symbol', 'iex_id')
      aggregate = params.fetch('aggregate', 1)

      status, result = @iex_service.get_chart_data(
        period,
        symbol: symbol,
        iex_id: iex_id,
        aggregate: aggregate.to_i
      )

      if status
        entries = result[:data]
        if entries.any?
          render json: {
            symbol: result[:symbol],
            currency: result[:currency],
            data: entries
          }
        else
          raise ActiveRecord::RecordNotFound, "not_found"
        end
      else
        raise ActionController::BadRequest, result
      end
    end

    def search
      term = params['q']

      status, result = @iex_service.search_symbols(term)

      if status
        if result.any?
          render json: result.map{ |record| record.serializable_hash(except: [:id, :created_at, :updated_at]) }
        else
          raise ActiveRecord::RecordNotFound, "not_found"
        end
      else
        raise ActionController::BadRequest, result
      end
    end
  end
end
