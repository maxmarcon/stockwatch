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
    # this iex_id does not exists in iex_symbols
    "iexId": "IEX_5043564631472D52",
    "region": "DE",
    "currency": "EUR",
    "isEnabled": true
  }
]

RESPONSE_UNEXPECTED_FORMAT = {hello: "baby"}

ISIN_LOOKUP_CORRECT_RESPONSE = [
  {
    "symbol": "CNDX-LN",
    "region": "GB",
    "exchange": "LON",
    "iexId": "IEX_485A304E42592D52"
  },
  {
    "symbol": "CNDX-NA",
    "region": "NL",
    "exchange": "AMS",
    "iexId": "IEX_485A304E42592D99"
  }
]

MISSING_ISIN = 'DE0009848120'

class IexServiceTest < ActiveSupport::TestCase

  def setup
    @service = IexService.new(
      {
        "base_url" => "https://fake.api.com/",
        access_token: "FAKE_TOKEN",
        'symbol_lists' => SYMBOL_LISTS,
        'mapping_max_age' => 2.weeks
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

    @rest_post_response_throwing_rest_client_error = ->(_,_,_){
      raise RestClient::NotFound
    }

    @rest_should_never_be_called = ->(_,_,_) {
      raise "should not be called"
    }

    @isin_lookup_correct_response = Minitest::Mock.new
    @isin_lookup_correct_response.expect :body, ISIN_LOOKUP_CORRECT_RESPONSE.to_json

    @isin_lookup_empty_response = Minitest::Mock.new
    @isin_lookup_empty_response.expect :body, [].to_json
  end

  test '#init_symbols load symbols from the api' do

    preexisting = IexSymbol.count

    RestClient.stub :get, @correct_response do
      @service.init_symbols
    end

    assert_equal preexisting + REST_CORRECT_RESPONSE_LIST_2.count + REST_CORRECT_RESPONSE_LIST_1.count-1, IexSymbol.count

    (REST_CORRECT_RESPONSE_LIST_1 + REST_CORRECT_RESPONSE_LIST_2)
    .reject{ |record| record[:iexId] == "IEX_4A4B355446472D52" } # already existing
    .each do |record|
      assert IexSymbol.where(name: record[:name], symbol: record[:symbol], iex_id: record[:iexId]).exists?
    end

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
      e = assert_raises ApiService::UnexpectedResponseError do
        @service.init_symbols
      end

      assert_equal 'Received response of wrong type: Hash, expected Array', e.message
    end

    @response_unexpected_format.verify
  end

  test "#init_symbols raises if RestClient raises exception" do
    RestClient.stub :get, @rest_response_throwing_rest_client_error do
      e = assert_raises RestClient::ExceptionWithResponse do
        @service.init_symbols
      end
    end
  end

  test "#get_by_isin does not call API, returns symbols for existing new mapping" do

    RestClient.stub :post, @rest_should_never_be_called do
      res, symbols = @service.get_by_isin(iex_isin_mappings(:mapping_1).isin)
      assert res
      assert_equal 2, symbols.size
      iex_symbols(:iex_1, :iex_2).each do |symbol|
        assert_includes symbols, symbol
      end
    end
  end

  test "#get_by_isin calls API for old mapping" do
    old_isin = iex_isin_mappings(:old_mapping).isin

    RestClient.stub :post, @isin_lookup_correct_response do
      res, symbols = @service.get_by_isin(old_isin)

      assert res

      assert_equal 1, symbols.size
      assert_includes symbols, iex_symbols(:iex_1)
    end

    @isin_lookup_correct_response.verify
    # 1 stale mapping should have been deleted and 2 new ones be created
    assert_equal 2, IexIsinMapping.where(isin: old_isin).count
  end

  test "#get_by_isin calls API for non-existing mapping" do

    RestClient.stub :post, @isin_lookup_correct_response do
      res, symbols = @service.get_by_isin(MISSING_ISIN)

      assert res

      assert_equal 1, symbols.size
      assert_includes symbols, iex_symbols(:iex_1)
    end

    assert_equal 2, IexIsinMapping.where(isin: MISSING_ISIN).count
    @isin_lookup_correct_response.verify
  end

  test "#get_by_isin records the fact that an API call did not return a mapping" do

    RestClient.stub :post, @isin_lookup_empty_response do
      res, symbols = @service.get_by_isin(MISSING_ISIN)

      assert res

      assert symbols.empty?
    end

    assert IexIsinMapping.where(isin: MISSING_ISIN, iex_id: nil).exists?
    @isin_lookup_empty_response.verify
  end


  test "#get_by_isin logs if response from API is invalid json" do

    logger_mock = Minitest::Mock.new
    logger_mock.expect :error, nil, [JSON::ParserError]

    RestClient.stub :post, @response_invalid_json do
      Rails.stub :logger, logger_mock do
        res, symbols = @service.get_by_isin(MISSING_ISIN)

        assert res

        assert symbols.empty?
      end
    end

    @response_invalid_json.verify
    logger_mock.verify
    assert IexIsinMapping.where(isin: MISSING_ISIN).none?
  end

  test "#get_by_isin logs if response from has invalid format" do

    logger_mock = Minitest::Mock.new
    logger_mock.expect :error, nil, [ApiService::UnexpectedResponseError]

    RestClient.stub :post, @response_unexpected_format do
      Rails.stub :logger, logger_mock do
        res, symbols = @service.get_by_isin(MISSING_ISIN)

        assert res

        assert symbols.empty?
      end
    end

    @response_unexpected_format.verify
    logger_mock.verify
    assert IexIsinMapping.where(isin: MISSING_ISIN).none?
  end

  test "#get_by_isin logs error if RestClient raises exception" do

    logger_mock = Minitest::Mock.new
    logger_mock.expect :error, nil, ["Received error response from IEX: Not Found"]

    RestClient.stub :post, @rest_post_response_throwing_rest_client_error do
      Rails.stub :logger, logger_mock do
        res, symbols = @service.get_by_isin(MISSING_ISIN)

        assert res

        assert symbols.empty?
      end
    end

    logger_mock.verify
    assert IexIsinMapping.where(isin: MISSING_ISIN).none?
  end

  test "#get_by_isin returns error if isin has invalid format" do
    res, error = @service.get_by_isin("DE12345678AI")

    assert_not res
    assert_equal :wrong_format, error
  end

  test "#get_by_isin returns empty array for isin whose look-up failed" do
    res, symbols = @service.get_by_isin(iex_isin_mappings(:mapping_3).isin)

    assert res
    assert symbols.empty?
  end

  test "#get_by_isin returns empty array for isin without symbols in iex_symbols" do
    res, symbols = @service.get_by_isin(iex_isin_mappings(:mapping_4).isin)

    assert res
    assert symbols.empty?
  end
end
