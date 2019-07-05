class IexService
  SYMBOL_ATTRS = %w(symbol exchange name date type iex_id region currency)
  ISIN_FORMAT = /^[A-Z]{2}\w{9}\d$/
  DEFAULT_MAPPING_MAX_AGE = 1.day

  def initialize(config = {})
    @config = Rails.configuration.iex.merge(Rails.application.credentials.iex, config.reject{ |k| k == 'api_service'})
    @api_service = ApiService.new({"iex" => @config}.merge(config.fetch("api_service", {})))

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
    max_age = @config.fetch('mapping_max_age', DEFAULT_MAPPING_MAX_AGE)
    if max_age.is_a?(ActiveSupport::Duration)
      max_age
    else
      max_age.seconds
    end
  end

  # Fetches IexSymbol(s) by ISIN
  def get_by_isin(isin)
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

  def fetch_time_series(iex_symbol, period)

  end


  private

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
    rescue ApiService::UnexpectedResponseError, JSON::ParserError => e
      Rails.logger.error(e)
    end
  end

  def fetch_symbol_list(symbol_list)
    begin
      status, response_body = @api_service.get :iex, symbol_list

      if status
        Rails.logger.info("Fetched #{response_body.size} records from list #{symbol_list}")

        saved = response_body.reduce(0){ |saved, record| saved + (store_symbol(record) ? 1 : 0) }

        Rails.logger.info("Stored #{saved} Iex symbols")
      end
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
  end

  def symbol_lists
    @config['symbol_lists'] || []
  end
end
