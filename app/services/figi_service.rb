class FigiService

  DEFAULT_MAX_AGE = 86400
  REST_CLIENT_OPTIONS = {content_type: :json, accept: :json}
  PERMITTED_PARAMS = %w(name ticker unique_id exch_code)

  def initialize(conf_override)
    @conf_override = conf_override
    @base_url = config['base_url']
    @max_age = (config['max_age'] || DEFAULT_MAX_AGE).seconds
    RestClient.log = Rails.logger

    raise 'base_url must be specified in figi configuration' unless @base_url
  end

  def get_by_isin(isins, force_update: false)
    updated_at = Figi.where(isin: isins).group(:isin).minimum(:updated_at)

    to_update = isins.select{ |isin| force_update || updated_at[isin].nil? || updated_at[isin] < @max_age.ago }

    update_by_isin(to_update) if to_update.any?

    Figi.where(isin: isins).to_a
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

  def config
    Rails.configuration.figi.merge(@conf_override)
  end

  def update_by_isin(isins)
    Rails.logger.info("fetching ISINs #{isins}")

    response = RestClient.post "v2/mapping",
      isins.map{ |isin| {idType: 'ID_ISIN', idValue: isin}}.to_json, REST_CLIENT_OPTIONS

    json_body = JSON.parse(response.body)
    raise "Received response of wrong type: #{json_body.class}, expected array" unless json_body.is_a? Array

    saved = 0

    #TODO: need to delete old FIGIs that don't appear in the new results
    json_body.each_with_index do |mapping, i|
      mapping.fetch('data', []).each do |record|
        figi = Figi.find_or_initialize_by(figi: record['figi'])
        figi.isin = isins[i]
        figi.assign_attributes(
          record.map{ |k,v| [k.underscore, v]}.to_h.select{ |k,_| k.in? PERMITTED_PARAMS }
        )

        if figi.save
          saved += 1
        else
          Rails.logger.error("Unable to save figi #{figi.figi}: #{figi.errors.full_messages.join(', ')}")
        end
      end
    end

    Rails.logger.info("Saved #{saved} figis")
  end
end
