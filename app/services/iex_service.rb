class IexService

  SYMBOL_ATTRS = %w(symbol exchange name date type iex_id region currency)

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

  private

  def fetch_symbol_list(symbol_list)
    begin
      response = RestClient.get URI.join(base_url, symbol_list).to_s, {params: {token: access_token}, accept: :json}

      json_body = JSON.parse(response.body)

      raise "Received response of wrong type: #{json_body.class}, expected Array" unless json_body.is_a? Array

      Rails.logger.info("Fetched #{json_body.size} records from list #{symbol_list}")

      saved = json_body.reduce(0){ |saved, record| saved + (store_symbol(record) ? 1 : 0) }

      Rails.logger.info("Stored #{saved} Iex symbols")

    rescue RestClient::ExceptionWithResponse => e
      Rails.logger.error("Received error response from IEX: #{e}")
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
