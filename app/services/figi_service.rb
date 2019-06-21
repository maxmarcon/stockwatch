class FigiService
  class UnexpectedResponseError < StandardError
    def initialize(received, expected = Array)
      @received = received
      @expected = expected
    end

    def message
      "Received response of wrong type: #{@received.class}, expected #{@expected}"
    end
  end

  DEFAULT_MAX_AGE = 86400
  REST_CLIENT_OPTIONS = {content_type: :json, accept: :json}
  PERMITTED_PARAMS = %w(name ticker unique_id exch_code)

  def initialize(config = {})
    @config = Rails.configuration.figi.merge(config)
    @base_url = @config['base_url']
    @max_age = (@config['max_age'] || DEFAULT_MAX_AGE).seconds
    RestClient.log = Rails.logger

    raise 'base_url must be specified in figi configuration' unless @base_url
  end

  def index_by_isin(isins, force_update: false)
    updated_at = Figi.where(isin: isins).group(:isin).minimum(:updated_at)

    isins_to_update = isins.select{ |isin| force_update || updated_at[isin].nil? || updated_at[isin] < @max_age.ago }

    update_isins(isins_to_update) if isins_to_update.any?

    Figi.where(isin: isins).group_by(&:isin)
  end

  def delete_by_isin(isins)
    Rails.logger.info("deleting all FIGI entries with ISIN: #{isins}")
    Figi.where(isin: isins).delete_all
  end

  def delete_all
    Rails.logger.info("deleting all FIGI entries")
    Figi.delete_all
  end

  private

  def update_isins(isins)
    Rails.logger.info("fetching ISINs #{isins}")

    begin
      response = RestClient.post URI.join(@base_url, "mapping").to_s,
        isins.map{ |isin| {idType: 'ID_ISIN', idValue: isin}}.to_json, REST_CLIENT_OPTIONS

      process_response(response, isins)
    rescue RestClient::ExceptionWithResponse => e
      Rails.logger.error("Received error response from OpenFIGI: #{e}")
    rescue UnexpectedResponseError, JSON::ParserError => e
      Rails.logger.error(e)
    end
  end

  def process_response(response, isins)
    json_body = JSON.parse(response.body)

    raise UnexpectedResponseError, json_body unless json_body.is_a? Array

    saved = 0

    json_body.each_with_index do |mapping, i|
      # Results for isins[i]
      isin = isins[i]

      if mapping.has_key?('data')
        records = mapping['data']

        saved += records.reduce(0) do
          |saved, record|
          saved + (create_or_update_figi_from_record(record, isin) ? 1 : 0)
        end
        # remove stale FIGIs for this ISIN
        Figi.where(isin: isin).where.not(figi: records.map{ |r| r['figi'] }).delete_all if records.any?
      else
        Rails.logger.error("Results for ISIN #{isin} not found. Error: #{mapping['error']}")
      end
    end

    Rails.logger.info("Saved #{saved} figis")
  end

  def create_or_update_figi_from_record(record, isin)

    figi = Figi.find_or_initialize_by(figi: record['figi'])
    figi.isin = isin
    figi.assign_attributes(
      record.map{ |k,v| [k.underscore, v]}.to_h.select{ |k,_| k.in? PERMITTED_PARAMS }
    )

    if figi.save
      true
    else
      Rails.logger.error("Unable to save figi #{figi.figi}: #{figi.errors.full_messages.join(', ')}")
      false
    end
  end
end
