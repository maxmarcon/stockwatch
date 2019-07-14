class IexService
  SYMBOL_ATTRS = %w(symbol exchange name date type iex_id region currency)
  TIME_PERIODS = %w(1y 2y 5y 1m 3m 6m)
  ISIN_FORMAT = /^[A-Z]{2}\w{9}\d$/

  def initialize(config = {})
    @config = Rails.configuration.iex.merge(Rails.application.credentials.iex, config.except('api_service'))
    @api_service = ApiService.new({"iex" => @config}.merge(config.fetch('api_service', {})))

    RestClient.log = Rails.logger
  end

  def init_symbols
    symbol_lists.each{ |symbol_list| fetch_symbol_list(symbol_list) }
  end

  def delete_symbols
    IexSymbol.delete_all
    Rails.logger.info("Deleted all Iex symbols")
  end

  def mapping_max_age
    max_age = @config['mapping_max_age']
    if max_age.nil? || max_age.is_a?(ActiveSupport::Duration)
      max_age
    else
      max_age.seconds
    end
  end

  # Fetches IexSymbol(s) by ISIN
  def get_symbols_by_isin(isin)
    isin.upcase!

    if isin =~ ISIN_FORMAT
      oldest_isin_update = IexIsinMapping.where(isin: isin).minimum(:updated_at)
      if oldest_isin_update.nil? || oldest_isin_update < mapping_max_age.ago
        look_up_isin(isin)
      end
      [true, IexSymbol.joins(:iex_isin_mapping).where(iex_isin_mappings: {isin: isin}).to_a]
    else
      [false, :wrong_format]
    end
  end

  def get_chart_data(period, iex_id: nil, symbol: nil)
    return [:error, "You need to specify either a symbol or a iex_id"] if [iex_id, symbol].all?(&:nil?)
    return [:error, "You can only specify either a symbol or a iex_id but not both"] if [iex_id, symbol].all?
    return [:error, "Invalid time period #{period}, must be one of: #{TIME_PERIODS}"] unless period.in?(TIME_PERIODS)

    if iex_id
      symbol = IexSymbol.find_by(iex_id: iex_id)

      return [:error, "ID #{iex_id} was not found"] unless symbol
    end

    if symbol.is_a?(IexSymbol)
      symbol = symbol.symbol
    end

    IexChartEntry.where(symbol: symbol).where("date >= ?", parse_period(period).ago.to_date).to_a
  end

  private

  def parse_period(period)

    m = period.match(/(\d+)([my])/)
    if m
      val = m[1].to_i
      time_period = case m[2]
      when 'm'
        :month
      when 'y'
        :year
      end
      val.send time_period
    end
  end

  def look_up_isin(isin)
    begin
      status, response_body = @api_service.post :iex, 'ref-data/isin', { isin: [isin] }

      if status
        iex_ids = response_body.map{ |record| record['iexId'] }

        deleted = IexIsinMapping.where(isin: isin).delete_all
        Rails.logger.info("deleted #{deleted} stale isin mappings")

        created = if iex_ids.empty?
          IexIsinMapping.create(isin: isin, iex_id: nil)
        else
          iex_ids.count{ |iex_id| IexIsinMapping.create(iex_id: iex_id, isin: isin).persisted? }
        end

        Rails.logger.info("created #{created} new isin mappings")
      end

    rescue RestClient::ExceptionWithResponse => e
      Rails.logger.error("Received error response from IEX: #{e}")
    rescue ApiService::UnexpectedResponseError, ActiveRecord::RecordNotUnique, JSON::ParserError => e
      Rails.logger.error(e)
    end
  end

  def fetch_symbol_list(symbol_list)
    status, response_body = @api_service.get :iex, symbol_list

    if status
      Rails.logger.info("Fetched #{response_body.size} records from list #{symbol_list}")

      saved = response_body.reduce(0){ |saved, record| saved + (store_symbol(record) ? 1 : 0) }

      Rails.logger.info("Stored #{saved} Iex symbols")
    end
  end

  def store_symbol(record)
    begin
      new_symbol = IexSymbol.create(record.to_a.map{ |k,v| [k.underscore, v] }.to_h.select{ |k,_| k.in? SYMBOL_ATTRS })
      if new_symbol.persisted?
        true
      else
        Rails.logger.debug("Could not store symbol from record #{record}, errors: #{new_symbol.errors.full_messages.join(', ')}")
        false
      end
    rescue ActiveRecord::RecordNotUnique => e
      Rails.logger.error(e)
      false
    end
  end

  def symbol_lists
    @config['symbol_lists'] || []
  end
end
