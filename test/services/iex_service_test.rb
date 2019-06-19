require 'test_helper'

SYMBOL_LISTS = [
  'ref-data/list1',
  'ref-data/list2'
]

REST_CORRECT_RESPONSE_LIST_1 = [
  {
    "symbol": "00XJ-GY",
    "exchange": "ETR",
    "name": "ETFS EUR Daily Hedged Agriculture DJ-UBS ED",
    "date": "2019-06-19",
    "type": "et",
    "iexId": "IEX_465250385A522D52",
    "region": "DE",
    "currency": "EUR",
    "isEnabled": true
  },
  {
    "symbol": "00XK-GY",
    "exchange": "ETR",
    "name": "ETFS EUR Daily Hedged All Commodities DJ-UBS ED",
    "date": "2019-06-19",
    "type": "et",
    # this iexId already exists in the fixture
    "iexId": "IEX_4A4B355446472D52",
    "region": "DE",
    "currency": "EUR",
    "isEnabled": true
  },
  {
    "symbol": "00XM-GY",
    "exchange": "ETR",
    "name": "ETFS EUR Daily Hedged WTI Crude Oil (German Cert.)",
    "date": "2019-06-19",
    "type": "et",
    "iexId": "IEX_4D31355251442D52",
    "region": "DE",
    "currency": "EUR",
    "isEnabled": true
  }
]


REST_CORRECT_RESPONSE_LIST_2 = [
  {
    "symbol": "00XR-GY",
    "exchange": "ETR",
    "name": "ETFS EUR Daily Hedged Silver (German Cert.)",
    "date": "2019-06-19",
    "type": "et",
    "iexId": "IEX_4E53503759592D52",
    "region": "DE",
    "currency": "EUR",
    "isEnabled": true
  },
  {
    "symbol": "00XS-GY",
    "exchange": "ETR",
    "name": "ETFS EUR Daily Hedged Wheat (German Cert.)",
    "date": "2019-06-19",
    "type": "et",
    "iexId": "IEX_5043564631472D52",
    "region": "DE",
    "currency": "EUR",
    "isEnabled": true
  }
]

RESPONSE_UNEXPECTED_FORMAT = {hello: "baby"}

class IexServiceTest < ActiveSupport::TestCase

  def setup
    @service = IexService.new(
      {
        "base_url" => "https://fake.api.com/",
        access_token: "FAKE_TOKEN",
        'symbol_lists' => SYMBOL_LISTS
      }
    )

    @correct_response = MiniTest::Mock.new
    @correct_response.expect :body, REST_CORRECT_RESPONSE_LIST_1.to_json
    @correct_response.expect :body, REST_CORRECT_RESPONSE_LIST_2.to_json

    @response_invalid_json = MiniTest::Mock.new.expect :body, '{invalid json: }'
    @response_unexpected_format = Minitest::Mock.new.expect :body, RESPONSE_UNEXPECTED_FORMAT.to_json

    @rest_response_throwing_rest_client_error = ->(_,_){
      raise RestClient::NotFound
    }
  end

  test '#init_symbols load symbols from the api' do

    preexisting = IexSymbol.count

    RestClient.stub :get, @correct_response do
      @service.init_symbols
    end

    assert_equal preexisting + REST_CORRECT_RESPONSE_LIST_2.count + REST_CORRECT_RESPONSE_LIST_1.count-1, IexSymbol.count

    @correct_response.verify
  end

  test '#delete_symbols deletes all symbols' do
    assert IexSymbol.any?

    @service.delete_symbols

    assert IexSymbol.none?
  end

  test "#init_symbols raises if response is invalid json" do

    RestClient.stub :get, @response_invalid_json do
      assert_raises JSON::ParserError do
        @service.init_symbols
      end
    end

    @response_invalid_json.verify
  end


  test "#init_symbols raises if response has unexpected format" do

    RestClient.stub :get, @response_unexpected_format do
      e = assert_raises RuntimeError do
        @service.init_symbols
      end

      assert_equal 'Received response of wrong type: Hash, expected Array', e.message
    end

    @response_unexpected_format.verify
  end

  test "#init_symbols logs error if RestClient raises exception" do
    logger_mock = Minitest::Mock.new
    logger_mock.expect :error, nil, ["Received error response from IEX: Not Found"]
    logger_mock.expect :error, nil, ["Received error response from IEX: Not Found"]

    RestClient.stub :get, @rest_response_throwing_rest_client_error do
      Rails.stub :logger, logger_mock do
        @service.init_symbols
      end
    end

    logger_mock.verify
  end
end
