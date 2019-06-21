class IexService
  class UnexpectedResponseError < StandardError
    def initialize(received, expected = Array)
      @received = received
      @expected = expected
    end

    def message
      "Received response of wrong type: #{@received.class}, expected #{@expected}"
    end
  end

  SYMBOL_ATTRS = %w(symbol exchange name date type iex_id region currency)
  ISIN_FORMAT = /^[A-Z]{2}\w{9}\d$/

  def initialize(config = {})
    @config = Rails.configuration.iex.merge(Rails.application.credentials.iex, config)
    RestClient.log = Rails.logger
  end

  def init_symbols
    symbol_lists.each{ |symbol_list| fetch_symbol_list(symbol_list) }
  end

  def delete_symbols
    IexSymbol.delete_all
    Rails.logger.info("Deleted all Iex symbols")
  end

  # Fetches IexSymbol(s) by ISIN
  def get_by_isin(isin)
    isin.upcase!

    if isin =~ ISIN_FORMAT
      if IexIsinMapping.where(isin: isin).none?
        look_up_isin(isin)
      end
      [true, IexSymbol.joins(:iex_isin_mapping).where(iex_isin_mappings: {isin: isin}).to_a]
    else
      [false, :wrong_format]
    end
  end

  private

  def look_up_isin(isin)
    begin
      records = parse_response(RestClient.post URI.join(base_url, 'ref-data/isin').to_s, { token: access_token, isin: [isin] }.to_json, {content_type: :json, accept: :json})

      iex_ids = records.map{ |record| record['iexId'] }

      created = if records.empty?
        IexIsinMapping.create(isin: isin, iex_id: nil)
      else
        iex_ids.count{ |iex_id| IexIsinMapping.create(iex_id: iex_id, isin: isin).persisted? }
      end

      Rails.logger.info("created #{created} new isin mappings")

    rescue RestClient::ExceptionWithResponse => e
      Rails.logger.error("Received error response from IEX: #{e}")
    rescue UnexpectedResponseError, JSON::ParserError => e
      Rails.logger.error(e)
    end
  end

  def fetch_symbol_list(symbol_list)
    begin
      records = parse_response(RestClient.get URI.join(base_url, symbol_list).to_s, {params: {token: access_token}, accept: :json})

      Rails.logger.info("Fetched #{records.size} records from list #{symbol_list}")

      saved = records.reduce(0){ |saved, record| saved + (store_symbol(record) ? 1 : 0) }

      Rails.logger.info("Stored #{saved} Iex symbols")
    end
  end

  def parse_response(response)
    json_body = JSON.parse(response.body)

    raise UnexpectedResponseError, json_body unless json_body.is_a? Array

    json_body
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

  def base_url
    @config['base_url'] or raise "Iex: base_url not specified"
  end

  def access_token
    @config[:access_token] or raise "Iex: no access_token"
  end

  def symbol_lists
    @config['symbol_lists'] || []
  end
end
