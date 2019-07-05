class ApiService
  DEFAULT_CALL_MAX_AGE = 12.hours

  class UnexpectedResponseError < StandardError
    def initialize(received, expected = Array)
      @received = received
      @expected = expected
    end

    def message
      "Received response of wrong type: #{@received.class}, expected #{@expected}"
    end
  end

  def initialize(config = {})
    @config = Rails.configuration.api_service.merge(config)
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
    age = @config.fetch("call_max_age", DEFAULT_CALL_MAX_AGE)
    if !age.nil? && !age.is_a?(ActiveSupport::Duration)
      age.seconds
    else
      age
    end
  end

  def get(api, path, params = {}, expected = Array)
    execute(api, :get, path, params, expected)
  end

  def post(api, path, params = {}, expected = Array)
    execute(api, :post, path, params, expected)
  end

  def execute(api, api_method, path, params = {}, expected = Array)
    call_hash = self.class.compute_hash(path, params)

    if ApiCall.called?(api, call_hash, max_age)
      Rails.logger.info("skipping API call to #{[api, api_method, path]} because executed in the last #{max_age.inspect}")

      [false, :called_recently]
    else
      if params.is_a?(Hash)
        # let's add credentials if any are needed
        effective_params = if access_token(api)
          {token: access_token(api)}
        else
          {}
        end

        effective_params.merge(params)
      else
        effective_params = params.dup
      end

      response = case api_method.to_sym
      when :post
        RestClient.post(
          URI.join(base_url(api), path).to_s,
          effective_params.to_json,
          {content_type: :json, accept: :json}
        )

      when :get
        RestClient.get(
          URI.join(base_url(api), path).to_s,
          {content_type: :json, accept: :json, params: effective_params}
        )
      else
        raise "Supported methods are get or post, was passed #{api_method}"
      end

      response_body = JSON.parse(response.body)

      raise UnexpectedResponseError.new(response_body, expected) unless response_body.is_a?(expected)

      ApiCall.record_call(api, call_hash)

      [true, response_body]
    end
  end
end
