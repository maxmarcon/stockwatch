require 'test_helper'

class ApiServiceTest < ActiveSupport::TestCase

  REST_GOOD_RESPONSE = [1,2,3]

  REST_UNEXPECED_RESPONSE = {
    "a" => 1
  }

  REST_MALFORMED_RESPONSE = "{ not json..."
  CALL = { path: "CALL", params: {"say" => "hello"}.freeze }

  def setup

    @api_service = ApiService.new({
                                    "iex" => {
                                      "base_url" => "https://fakeapi.com",
                                      :access_token => "FAKE_TOKEN"
                                    },
                                    "call_max_age" => 1.day
    })

    @rest_correct_response = Minitest::Mock.new.expect :body, REST_GOOD_RESPONSE.to_json
    @rest_malformed_response = Minitest::Mock.new.expect :body, REST_MALFORMED_RESPONSE
    @rest_unexpected_response = Minitest::Mock.new.expect :body, REST_UNEXPECED_RESPONSE.to_json

    @rest_should_never_be_called = ->(_,_,_) {
      raise "should not be called"
    }
  end

  test "#execute executes call" do
    RestClient.stub :post, @rest_correct_response do
      assert_equal [true, REST_GOOD_RESPONSE],  @api_service.execute(:iex, :post, CALL[:path], CALL[:params])
    end

    @rest_correct_response.verify
  end

  test "#execute does not execute recent call" do
    RestClient.stub :post, @rest_correct_response do
      assert_equal [true, REST_GOOD_RESPONSE],  @api_service.execute(:iex, :post, CALL[:path], CALL[:params])
    end

    RestClient.stub :post, @rest_should_never_be_called do
      assert_equal [false, :called_recently], @api_service.execute(:iex, :post, CALL[:path], CALL[:params])
    end

    @rest_correct_response.verify
  end

  test "#execute raises if response is not json" do
    RestClient.stub :post, @rest_malformed_response do
      assert_raises(JSON::ParserError) do
        @api_service.execute :iex, :post, CALL[:path], CALL[:params]
      end
    end
  end

  test "#execute raises if response body has unexpected type" do
    RestClient.stub :post, @rest_unexpected_response do
      assert_raises(ApiService::UnexpectedResponseError) do
        @api_service.execute :iex, :post, CALL[:path], CALL[:params]
      end
    end
  end

  test "#xecute raises if passed unsupported api method" do
    e = assert_raises(RuntimeError) do
      @api_service.execute :iex, :made_up_method, CALL[:path], CALL[:params]
    end

    assert_equal "Supported methods are get or post, was passed made_up_method", e.message
  end
end
