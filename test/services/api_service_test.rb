require 'test_helper'

class ApiServiceTest < ActiveSupport::TestCase

  REST_GOOD_RESPONSE = [1,2,3]

  REST_UNEXPECED_RESPONSE = {
    "a" => 1
  }

  REST_MALFORMED_RESPONSE = "{ not json..."
  OLD_CALL = { path: "old_call", params: {"say" => "hello"}.freeze }
  NEW_CALL = { path: "new_call", params: {"say" => "hello"}.freeze }
  CALL_MAX_AGE = 1.day

  def setup

    @api_service = ApiService.new({
                                    "iex" => {
                                      "base_url" => "https://fakeapi.com"
                                    },
                                    "call_max_age" => CALL_MAX_AGE
    })

    @rest_correct_response = Minitest::Mock.new.expect :body, REST_GOOD_RESPONSE.to_json
    @rest_malformed_response = Minitest::Mock.new.expect :body, REST_MALFORMED_RESPONSE
    @rest_unexpected_response = Minitest::Mock.new.expect :body, REST_UNEXPECED_RESPONSE.to_json

    @rest_should_never_be_called = ->(_,_,_) {
      raise "should not be called"
    }
  end

  test "#post executes and records new call" do
    RestClient.stub :post, @rest_correct_response do
      status, response = @api_service.post :iex, NEW_CALL[:path], NEW_CALL[:params]
      assert status
      assert_equal REST_GOOD_RESPONSE, response
    end

    @rest_correct_response.verify
    assert ApiCall.called? :iex, ApiService.compute_hash(NEW_CALL[:path], NEW_CALL[:params]), CALL_MAX_AGE
  end

  test "#post executes and updates old call" do
    old_call_hash = ApiService.compute_hash(OLD_CALL[:path], OLD_CALL[:params])
    ApiCall.create!(api: :iex, call_digest: old_call_hash, updated_at: 1.week.ago, created_at: 1.week.ago)
    assert_not ApiCall.called? :iex, old_call_hash, CALL_MAX_AGE

    RestClient.stub :post, @rest_correct_response do
      status, response = @api_service.post :iex, OLD_CALL[:path], OLD_CALL[:params]
      assert status
      assert_equal REST_GOOD_RESPONSE, response
    end

    @rest_correct_response.verify
    assert ApiCall.called? :iex, old_call_hash, CALL_MAX_AGE
  end


  test "#post does not execute recent call" do
    recent_call_hash = ApiService.compute_hash(OLD_CALL[:path], OLD_CALL[:params])
    api_call = ApiCall.create!(api: :iex, call_digest: recent_call_hash, updated_at: 5.hours.ago, created_at: 5.hours.ago)
    assert ApiCall.called? :iex, recent_call_hash, CALL_MAX_AGE

    RestClient.stub :post, @rest_should_never_be_called do
      assert_equal [false, :called_recently], @api_service.post(:iex, OLD_CALL[:path], OLD_CALL[:params])
    end

    assert ApiCall.called? :iex, recent_call_hash, CALL_MAX_AGE
  end

  test "#post raises if response is not json" do
    RestClient.stub :post, @rest_malformed_response do
      assert_raises(JSON::ParserError) do
        @api_service.post :iex, NEW_CALL[:path], NEW_CALL[:params]
      end
    end
  end

  test "#post raises if response body has unexpected type" do
    RestClient.stub :post, @rest_unexpected_response do
      assert_raises(ApiService::UnexpectedResponseError) do
        @api_service.post :iex, NEW_CALL[:path], NEW_CALL[:params]
      end
    end
  end
end
