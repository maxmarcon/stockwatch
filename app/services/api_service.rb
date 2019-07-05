class ApiService
  class UnexpectedResponseError < StandardError
    def initialize(received, expected = Array)
      @received = received
      @expected = expected
    end

    def message
      "Received response of wrong type: #{@received.class}, expected #{@expected}"
    end
  end

  DEFAULT_CALL_MAX_AGE = 1.hour

  def initialize(config = {})
    @config = {
      "figi" => Rails.configuration.figi,
      "iex" => Rails.configuration.iex.merge(Rails.application.credentials.iex),
      "call_max_age" => Rails.configuration.api_service['call_max_age'] || DEFAULT_CALL_MAX_AGE
    }.merge(config)
  end

  def base_url(api)
    @config.dig(api.to_s, 'base_url') or raise "you need to specify a base_url to call API #{api}"
  end

  def access_token(api)
    @config.dig(api.to_s, :access_token)
  end

  # For simplicity, the order of elements in params is taken into account, meaning
  # that diferent orderings will result in different hash values
  def self.compute_hash(path, params)
    Digest::MD5.hexdigest(
      {
        path: path,
        params: params.to_s
      }.to_s
    )
  end

  def max_age
    age = @config["call_max_age"]
    if !age.is_a?(ActiveSupport::Duration)
      age.seconds
    else
      age
    end
  end

  def post(api, path, params = {}, expected = Array)
    call_hash = self.class.compute_hash(path, params)

    if ApiCall.called?(api, call_hash, max_age)
      [false, :called_recently]
    else
      effective_params = if access_token(api)
        {token: access_token(api)}
      else
        {}
      end

      effective_params.merge(params)

      response = RestClient.post(
        URI.join(base_url(api), path).to_s,
        effective_params.to_json,
        {content_type: :json, accept: :json}
      )

      response_body = JSON.parse(response.body)

      raise UnexpectedResponseError.new(response_body, expected) unless response_body.is_a?(expected)

      ApiCall.record_call(api, call_hash)

      [true, response_body]
    end
  end
end