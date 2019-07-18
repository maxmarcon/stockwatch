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

CHART_CORRECT_RESPONSE = 1.upto(((1.month/1.day)*IexService::DAYS_THRESHOLD)).map do |i|
  {
    symbol: '1SSEMYMA2-MM',
    date: Date.current - i,
    close: 1000 - i,
    volume: 0,
    change: 0,
    change_percent: 0,
    change_over_time: 0
  }
end

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

    @rest_response_throwing_rest_client_error = proc {
      raise RestClient::NotFound
    }

    @rest_should_never_be_called = proc {
      raise "should not be called"
    }

    @isin_lookup_correct_response = Minitest::Mock.new
    @isin_lookup_correct_response.expect :body, ISIN_LOOKUP_CORRECT_RESPONSE.to_json

    @isin_lookup_empty_response = Minitest::Mock.new
    @isin_lookup_empty_response.expect :body, [].to_json

    @chart_correct_response = Minitest::Mock.new
    @chart_correct_response.expect :body, CHART_CORRECT_RESPONSE.to_json
  end

  test '#initialize throws if access_token is missing' do

    e = assert_raise RuntimeError do
      IexService.new(
        {
          "base_url" => "https://fake.api.com/",
          'symbol_lists' => SYMBOL_LISTS,
          :access_token => nil,
          'mapping_max_age' => 2.weeks
        }
      )
    end

    assert_match "You need to specify the IEX access token", e.message
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

  test "#get_symbols_by_isin does not call API, returns symbols for existing new mapping" do

    RestClient.stub :post, @rest_should_never_be_called do
      res, symbols = @service.get_symbols_by_isin(iex_isin_mappings(:mapping_1).isin)
      assert res
      assert_equal 2, symbols.size
      iex_symbols(:iex_1, :iex_2).each do |symbol|
        assert_includes symbols, symbol
      end
    end
  end

  test "#get_symbols_by_isin calls API for old mapping" do
    old_isin = iex_isin_mappings(:old_mapping).isin

    RestClient.stub :post, @isin_lookup_correct_response do
      res, symbols = @service.get_symbols_by_isin(old_isin)

      assert res

      assert_equal 1, symbols.size
      assert_includes symbols, iex_symbols(:iex_1)
    end

    @isin_lookup_correct_response.verify
    # 1 stale mapping should have been deleted and 2 new ones be created
    assert_equal 2, IexIsinMapping.where(isin: old_isin).count
  end

  test "#get_symbols_by_isin calls API for non-existing mapping" do

    RestClient.stub :post, @isin_lookup_correct_response do
      res, symbols = @service.get_symbols_by_isin(MISSING_ISIN)

      assert res

      assert_equal 1, symbols.size
      assert_includes symbols, iex_symbols(:iex_1)
    end

    assert_equal 2, IexIsinMapping.where(isin: MISSING_ISIN).count
    @isin_lookup_correct_response.verify
  end

  test "#get_symbols_by_isin records the fact that an API call did not return a mapping" do

    RestClient.stub :post, @isin_lookup_empty_response do
      res, symbols = @service.get_symbols_by_isin(MISSING_ISIN)

      assert res

      assert symbols.empty?
    end

    assert IexIsinMapping.where(isin: MISSING_ISIN, iex_id: nil).exists?
    @isin_lookup_empty_response.verify
  end


  test "#get_symbols_by_isin logs if response from API is invalid json" do

    logger_mock = Minitest::Mock.new
    logger_mock.expect :error, nil, [JSON::ParserError]

    RestClient.stub :post, @response_invalid_json do
      Rails.stub :logger, logger_mock do
        res, symbols = @service.get_symbols_by_isin(MISSING_ISIN)

        assert res

        assert symbols.empty?
      end
    end

    @response_invalid_json.verify
    logger_mock.verify
    assert IexIsinMapping.where(isin: MISSING_ISIN).none?
  end

  test "#get_symbols_by_isin logs if response from API has invalid format" do

    logger_mock = Minitest::Mock.new
    logger_mock.expect :error, nil, [ApiService::UnexpectedResponseError]

    RestClient.stub :post, @response_unexpected_format do
      Rails.stub :logger, logger_mock do
        res, symbols = @service.get_symbols_by_isin(MISSING_ISIN)

        assert res

        assert symbols.empty?
      end
    end

    @response_unexpected_format.verify
    logger_mock.verify
    assert IexIsinMapping.where(isin: MISSING_ISIN).none?
  end

  test "#get_symbols_by_isin logs error if RestClient raises exception" do

    logger_mock = Minitest::Mock.new
    logger_mock.expect :error, nil, ["Received error response from IEX: Not Found"]

    RestClient.stub :post, @rest_response_throwing_rest_client_error do
      Rails.stub :logger, logger_mock do
        res, symbols = @service.get_symbols_by_isin(MISSING_ISIN)

        assert res

        assert symbols.empty?
      end
    end

    logger_mock.verify
    assert IexIsinMapping.where(isin: MISSING_ISIN).none?
  end

  test "#get_symbols_by_isin does not call API for partial isin" do
    RestClient.stub :post, @rest_should_never_be_called do
      res, symbols = @service.get_symbols_by_isin("DE00098")
      assert res
      assert_equal [iex_symbols(:iex_1), iex_symbols(:iex_2)], symbols
    end
  end

  test "#get_symbols_by_isin returns empty array for isin whose look-up failed" do
    RestClient.stub :post, @rest_should_never_be_called do
      res, symbols = @service.get_symbols_by_isin(iex_isin_mappings(:mapping_3).isin)
      assert res
      assert symbols.empty?
    end
  end

  test "#get_symbols_by_isin returns empty array for isin without symbols in iex_symbols" do
    RestClient.stub :post, @rest_should_never_be_called do
      res, symbols = @service.get_symbols_by_isin(iex_isin_mappings(:mapping_4).isin)
      assert res
      assert symbols.empty?
    end
  end

  test "#get_chart_data returns error if neither iex_id or isin is specified" do
    RestClient.stub :get, @rest_should_never_be_called do
      res, message = @service.get_chart_data('1m')
      assert_not res
      assert_equal 'You need to specify either a symbol or a iex_id', message
    end
  end

  test "#get_chart_data returns error if both symbol and iex_id are specified" do
    RestClient.stub :get, @rest_should_never_be_called do
      res, message = @service.get_chart_data('1m', iex_id: 'DE0009848119', symbol: 'AAX')
      assert_not res
      assert_equal "You can only specify either a symbol or a iex_id but not both", message
    end
  end

  test "#get_chart_data returns error if period is invalid" do
    RestClient.stub :get, @rest_should_never_be_called do
      res, message = @service.get_chart_data('10m', symbol: 'AAX')
      assert_not res
      assert_equal "Invalid time period 10m, must be one of: #{IexService::TIME_PERIODS}", message
    end
  end

  test "#get_chart_data returns error if iex_id can't be found" do
    iex_id = 'IEX_485A304E42592XXX'
    RestClient.stub :get, @rest_should_never_be_called do
      res, message = @service.get_chart_data('1m', iex_id: iex_id)
      assert_not res
      assert_equal "Unknown IEX_ID #{iex_id}", message
    end
  end

  test "#get_chart_data returns error if symbol can't be found" do
    symbol = '1SSEMYM1-XX'
    RestClient.stub :get, @rest_should_never_be_called do
      res, message = @service.get_chart_data('1m', symbol: symbol)
      assert_not res
      assert_equal "Unknown symbol #{symbol}", message
    end
  end

  test "#get_chart_data does not call API if days in DB are above or equal to the threshold and last entry is recent enough" do
    symbol = "1SSEMYM1-MM"
    expected = (1.month / 1.day)*IexService::DAYS_THRESHOLD

    RestClient.stub :get, @rest_should_never_be_called do
      res, result = @service.get_chart_data('1m', symbol: symbol)

      assert res
      assert result.has_key?(:data)
      assert_equal 'MXN', result[:currency]
      assert_equal (1.month / 1.day)*IexService::DAYS_THRESHOLD, result[:data].count
      result[:data].each do |chart_entry|
        assert_equal symbol, chart_entry.symbol
        assert chart_entry.serializable_hash.values.all?
      end
    end
  end

  test "#get_chart_data can retrieve data by iex_id" do
    iex_id = "IEX_485A304E42592D52"
    symbol = IexSymbol.find_by(iex_id: iex_id).symbol
    expected = (1.month / 1.day)*IexService::DAYS_THRESHOLD

    RestClient.stub :get, @rest_should_never_be_called do
      res, result = @service.get_chart_data('1m', iex_id: iex_id)

      assert res
      assert result.has_key?(:data)
      assert_equal 'MXN', result[:currency]
      assert_equal (1.month / 1.day)*IexService::DAYS_THRESHOLD, result[:data].count
      result[:data].each do |chart_entry|
        assert_equal symbol, chart_entry.symbol
        assert chart_entry.serializable_hash.values.all?
      end
    end
  end

  test "#get_chart_data calls API if days in DB are below the threshold" do
    symbol = "1SSEMYMA2-MM"
    expected = (1.month / 1.day)*IexService::DAYS_THRESHOLD

    RestClient.stub :get, @chart_correct_response do
      res, result = @service.get_chart_data('1m', symbol: symbol)

      assert res
      assert result.has_key?(:data)
      assert_equal 'MXN', result[:currency]
      assert_equal expected, result[:data].count
      result[:data].each do |chart_entry|
        assert_equal symbol, chart_entry.symbol
        assert chart_entry.serializable_hash.values.all?
      end
    end

    @chart_correct_response.verify
    assert_equal expected, IexChartEntry.where(symbol: symbol).count
  end

  test "#get_chart_data calls API if last entry is not recent enough" do
    symbol = "1SSEMYMA3-MM"
    expected = (1.month / 1.day)*IexService::DAYS_THRESHOLD + IexService::LAST_ENTRY_MAX_AGE_DAYS

    RestClient.stub :get, @chart_correct_response do
      res, result = @service.get_chart_data('1m', symbol: symbol)

      assert res
      assert result.has_key?(:data)
      assert_equal 'MXN', result[:currency]
      assert_equal expected, result[:data].count
      result[:data].each do |chart_entry|
        assert_equal symbol, chart_entry.symbol
        assert chart_entry.serializable_hash.values.all?
      end
    end

    @chart_correct_response.verify
    assert_equal expected, IexChartEntry.where(symbol: symbol).count
  end

  test "#get_chart_data logs if response from API is invalid json" do
    symbol = "1SSEMYMA2-MM"

    logger_mock = Minitest::Mock.new
    logger_mock.expect :error, nil, [JSON::ParserError]

    RestClient.stub :get, @response_invalid_json do
      Rails.stub :logger, logger_mock do
        @service.get_chart_data('1m', symbol: symbol)
      end
    end

    logger_mock.verify
    @response_invalid_json.verify
  end

  test "#get_chart_data logs if response from API has invalid format" do
    symbol = "1SSEMYMA2-MM"

    logger_mock = Minitest::Mock.new
    logger_mock.expect :error, nil, [ApiService::UnexpectedResponseError]

    RestClient.stub :get, @response_unexpected_format do
      Rails.stub :logger, logger_mock do
        @service.get_chart_data('1m', symbol: symbol)
      end
    end

    logger_mock.verify
    @response_unexpected_format.verify
  end

  test "#get_chart_data logs if REST client raises exception" do
    symbol = "1SSEMYMA2-MM"

    logger_mock = Minitest::Mock.new
    logger_mock.expect :error, nil, ["Received error response from IEX: Not Found"]

    RestClient.stub :get, @rest_response_throwing_rest_client_error do
      Rails.stub :logger, logger_mock do
        @service.get_chart_data('1m', symbol: symbol)
      end
    end

    logger_mock.verify
  end

  test "#search_symbols find symbols by iex_id" do

    assert_equal [true, [iex_symbols(:iex_1)]], @service.search_symbols('IEX_485A304E42592D52')
  end

  test "#search_symbols find symbols by symbol" do
    assert_equal [true, [iex_symbols(:iex_1)]], @service.search_symbols('1SSEMYM1-MM')
  end

  test "#search_symbols find symbols by isin" do
    RestClient.stub :post, @rest_should_never_be_called do
      assert_equal [true, [iex_symbols(:iex_1), iex_symbols(:iex_2)]], @service.search_symbols('DE0009848119')
    end
  end

  test "#search_symbols find symbols by partial isin" do
    RestClient.stub :post, @rest_should_never_be_called do
      assert_equal [true, [iex_symbols(:iex_1), iex_symbols(:iex_2)]], @service.search_symbols('DE00098')
    end
  end

  test "#search_symbols returns empty array if nothing is found" do
    assert_equal [true, []], @service.search_symbols('XXXXXXX')
  end

  test "#search_symbols returns error if empty search term is passed" do
    assert_equal [false, :search_term_missing], @service.search_symbols('')
  end

  test "#search_symbols returns error if nil search term is passed" do
    assert_equal [false, :search_term_missing], @service.search_symbols(nil)
  end
end
