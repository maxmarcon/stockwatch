class IexService
  SYMBOL_ATTRS = %w(symbol exchange name date type iex_id region currency)
  TIME_PERIODS = %w(1y 2y 5y 1m 3m 6m)
  ISIN_FORMAT = /^[A-Z]{2}\w{9}\d$/
  DAYS_THRESHOLD = 0.6
  LAST_ENTRY_MAX_AGE_DAYS = 3
  CHART_ENTRY_ATTRS = %w(symbol date close volume change change_percent change_over_time)

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

  def search_symbols(term)
    if term.present?
      query_top = IexSymbol
        .where('symbol ilike ?', "#{term}%")
        .or(IexSymbol.where('iex_id ilike ?', "#{term}%"))
        .order(:symbol)
        .limit(5)

      query_bottom = IexSymbol
        .where('symbol ilike ?', "%#{term}%")
        .or(IexSymbol.where('name ilike ?', "%#{term}%"))
        .order(:symbol)
        .limit(5)

      status, by_isin = get_symbols_by_isin(term)
      by_isin = [] unless status

      if (Rails.env.development?)
        Rails.logger.info(query_top.to_sql)
        Rails.logger.info(query_bottom.to_sql)
      end

      [true, (by_isin + query_top.to_a + query_bottom.to_a).uniq]
    else
      [false, :search_term_missing]
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
    end

    query = IexSymbol.includes(:iex_isin_mapping)
      .where("iex_isin_mappings.isin ilike ?", "%#{isin}%")
      .references(:iex_isin_mapping)
      .order(:symbol)
      .limit(5)

    Rails.logger.info(query.to_sql) if Rails.env.development?

    [
      true,
      query.select{ |iex_symbol| iex_symbol.isin = iex_symbol.iex_isin_mapping.isin}
    ]
  end

  def get_chart_data(period, iex_id: nil, symbol: nil)
    return [false, "You need to specify either a symbol or a iex_id"] if [iex_id, symbol].all?(&:nil?)
    return [false, "You can only specify either a symbol or a iex_id but not both"] if [iex_id, symbol].all?
    return [false, "Invalid time period #{period}, must be one of: #{TIME_PERIODS}"] unless period.in?(TIME_PERIODS)

    iex_symbol = if iex_id
      IexSymbol.find_by(iex_id: iex_id)
    else
      IexSymbol.find_by(symbol: symbol)
    end

    if iex_symbol
      time_period = parse_period(period)

      query = IexChartEntry.where(symbol: iex_symbol.symbol).where("date >= ?", time_period.ago.to_date)

      if query.count < (time_period/1.day)*DAYS_THRESHOLD ||
          (query.any? && (Date.current - query.maximum(:date)) > LAST_ENTRY_MAX_AGE_DAYS)
        fetch_chart_data(period, iex_symbol.symbol)
      end

      [true, {data: query.order(:date).to_a, currency: iex_symbol.currency}]
    else
      if iex_id
        [false, "Unknown IEX_ID #{iex_id}"]
      else
        [false, "Unknown symbol #{symbol}"]
      end
    end
  end

  private

  def fetch_chart_data(period, symbol)
    status, response_body = @api_service.get :iex, "stock/#{symbol}/chart/#{period}", {chartCloseOnly: true}

    if status
      saved = response_body.reduce(0){ |saved, record| saved + (store_chart_entry(record, symbol) ? 1 : 0) }

      Rails.logger.info("Stored #{saved} entries for symbol #{symbol}")
    end
  rescue RestClient::ExceptionWithResponse => e
    Rails.logger.error("Received error response from IEX: #{e}")
  rescue ApiService::UnexpectedResponseError, ActiveRecord::RecordNotUnique, JSON::ParserError => e
    Rails.logger.error(e)
  end

  def parse_period(period)
    m = period.match(/(\d+)([my])/)

    if m
      number = m[1].to_i
      time_period = case m[2]
      when 'm'
        :month
      when 'y'
        :year
      end
      number.send(time_period)
    end
  end

  def store_chart_entry(record, symbol)
    chart_entry = IexChartEntry.create(record.map{ |k,v| [k.underscore, v] }.to_h.select{ |k,_| k.in? CHART_ENTRY_ATTRS }.merge({symbol: symbol}))
    if chart_entry.persisted?
      true
    else
      Rails.logger.debug("Could not store chart entry from record #{record}, errors: #{chart_entry.errors.full_messages.join(', ')}")
      false
    end
  rescue ActiveRecord::RecordNotUnique => e
    Rails.logger.error(e)
    false
  end

  def look_up_isin(isin)
    status, response_body = @api_service.post :iex, 'ref-data/isin', { isin: [isin] }

    if status
      iex_ids = response_body.map{ |record| record['iexId'] }

      deleted = IexIsinMapping.where(isin: isin).delete_all
      Rails.logger.info("deleted #{deleted} stale isin mappings")

      created = if iex_ids.empty?
        IexIsinMapping.create(isin: isin, iex_id: nil)
      else
        iex_ids.count do |iex_id|
          IexIsinMapping.create(iex_id: iex_id, isin: isin).persisted?
        rescue ActiveRecord::RecordNotUnique => e
          Rails.logger.error(e)
          false
        end
      end

      Rails.logger.info("created #{created} new isin mappings")
    end

  rescue RestClient::ExceptionWithResponse => e
    Rails.logger.error("Received error response from IEX: #{e}")
  rescue ApiService::UnexpectedResponseError, ActiveRecord::RecordNotUnique, JSON::ParserError => e
    Rails.logger.error(e)
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

  def symbol_lists
    @config['symbol_lists'] || []
  end
end
