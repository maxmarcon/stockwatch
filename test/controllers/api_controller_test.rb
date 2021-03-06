require 'test_helper'

class ApiControllerTest < ActionDispatch::IntegrationTest

  def setup
    @rest_should_never_be_called = proc {
      raise "should not be called"
    }
  end

  test "GET /isin retrieves mapping to symbol" do
    isin = 'DE0009848119'

    RestClient.stub :get, @rest_should_never_be_called do
      get "/v1/isin/#{isin}", headers: {"Accept" => 'application/json' }
    end
    assert_response :success

    assert_equal 2, @response.parsed_body.count
    @response.parsed_body.each do |record|
      assert record.values_at("symbol", "exchange", "name", "date", "type", "iex_id", "region", "currency", "isin").all?
    end

    symbols = @response.parsed_body.map{ |record| record["symbol"] }
    assert symbols.include? '1SSEMYM1-MM'
    assert symbols.include? '1SSEMYMA2-MM'
  end

  test "GET /isin returns 404 Not Found with unknown ISIN" do
    isin = 'LU0767751091'

    RestClient.stub :get, @rest_should_never_be_called do
      get "/v1/isin/#{isin}", headers: {"Accept" => 'application/json' }
    end
    assert_response :not_found

    assert_equal 404, @response.parsed_body["status"]
    assert_equal "not_found", @response.parsed_body["message"]
  end

  test "GET /chart/:period returns the chart data by symbol" do
    symbol = '1SSEMYM1-MM'

    RestClient.stub :get, @rest_should_never_be_called do
      get "/v1/chart/1m", params: {symbol: symbol}, headers: {"Accept" => 'application/json' }
    end

    assert_response :ok

    json_response = @response.parsed_body
    assert json_response.has_key?("data")
    assert_equal 'MXN', json_response["currency"]
    assert_equal symbol, json_response["symbol"]
    assert_equal (1.month/1.day)*IexService::DAYS_THRESHOLD, json_response["data"].count
    json_response["data"].each do |record|
      assert record.values_at("date", "close").all?
    end
  end

  test "GET /chart/:period returns the chart data by iex_id" do
    iex_id = 'IEX_485A304E42592D52'

    RestClient.stub :get, @rest_should_never_be_called do
      get "/v1/chart/1m", params: {iex_id: iex_id}, headers: {"Accept" => 'application/json' }
    end

    assert_response :ok

    json_response = @response.parsed_body
    assert json_response.has_key?("data")
    assert_equal 'MXN', json_response["currency"]
    assert_equal IexSymbol.find_by(iex_id: iex_id).symbol, json_response["symbol"]
    assert_equal (1.month/1.day)*IexService::DAYS_THRESHOLD, json_response["data"].count
    json_response["data"].each do |record|
      assert record.values_at("date", "close").all?
    end
  end

  test "GET /chart/:period returns 400 Bad Request with invalid period" do
    symbol = '1SSEMYM1-MM'

    RestClient.stub :get, @rest_should_never_be_called do
      get "/v1/chart/2m", params: {symbol: symbol}, headers: {"Accept" => 'application/json' }
    end

    assert_response :bad_request

    assert_equal 400, @response.parsed_body["status"]
    assert_match "Invalid time period 2m", @response.parsed_body["message"]
  end

  test "GET /chart/:period returns 400 Bad Request with invalid max_points value" do
    symbol = '1SSEMYM1-MM'

    RestClient.stub :get, @rest_should_never_be_called do
      get "/v1/chart/1m", params: {max_points: 0, symbol: symbol}, headers: {"Accept" => 'application/json' }
    end

    assert_response :bad_request

    assert_equal 400, @response.parsed_body["status"]
    assert_match "Invalid max_points value", @response.parsed_body["message"]
  end

  test "GET /chart/:period returns 400 Bad Request if symbol is missing" do

    RestClient.stub :get, @rest_should_never_be_called do
      get "/v1/chart/1m", headers: {"Accept" => 'application/json' }
    end

    assert_response :bad_request

    assert_equal 400, @response.parsed_body["status"]
    assert_match "You need to specify either a symbol or a iex_id", @response.parsed_body["message"]
  end

  test "GET /chart/:period returns 400 Bad Request with unknown iex_id" do
    iex_id = 'IEX_485A304E42592D53'

    RestClient.stub :get, @rest_should_never_be_called do
      get "/v1/chart/1m", params: {iex_id: iex_id}, headers: {"Accept" => 'application/json'}
    end

    assert_response :bad_request

    assert_equal 400, @response.parsed_body["status"]
    assert_equal "Unknown IEX_ID #{iex_id}", @response.parsed_body["message"]
  end

  test "GET /chart/:period returns 400 Bad Request with unknown symbol" do
    symbol = '1SSEMYM1-XX'

    RestClient.stub :get, @rest_should_never_be_called do
      get "/v1/chart/1m", params: {symbol: symbol}, headers: {"Accept" => 'application/json'}
    end

    assert_response :bad_request

    assert_equal 400, @response.parsed_body["status"]
    assert_equal "Unknown symbol #{symbol}", @response.parsed_body["message"]
  end

  test "GET /chart/:period returns 404 Not Found if no chart data is available" do
    symbol = '1SSEMYMA4-MM'

    rest_empty_response = Minitest::Mock.new
    rest_empty_response.expect :body, ""

    RestClient.stub :get, rest_empty_response do
      get "/v1/chart/1m", params: {symbol: symbol}, headers: {"Accept" => 'application/json' }
    end

    assert_response :not_found

    rest_empty_response.verify
    assert_equal 404, @response.parsed_body["status"]
    assert_equal "not_found", @response.parsed_body["message"]
  end

  test "GET /search returns symbols when symbol is passed as search term" do
    symbol = '1SSEMYMA4-MM'

    get "/v1/search", params: {q: symbol}, headers: {"Accept" => 'application/json' }

    assert_response :ok
    json_response = @response.parsed_body
    assert 1, json_response.length
    assert json_response[0].values_at("symbol", "exchange", "name", "date", "type", "iex_id", "region", "currency").all?
    assert_equal symbol, json_response[0]["symbol"]
  end

  test "GET /search returns symbols when iex_id is passed as search term" do
    iex_id = 'IEX_485A304E42592D52'

    get "/v1/search", params: {q: iex_id}, headers: {"Accept" => 'application/json' }

    assert_response :ok
    json_response = @response.parsed_body
    assert 1, json_response.length
    assert json_response[0].values_at("symbol", "exchange", "name", "date", "type", "iex_id", "region", "currency").all?
    assert_equal iex_id, json_response[0]["iex_id"]
  end

  test "GET /search returns symbols when isin is passed as search term" do
    isin = 'DE0009848119'

    get "/v1/search", params: {q: isin}, headers: {"Accept" => 'application/json' }

    assert_response :ok
    json_response = @response.parsed_body
    assert 2, json_response.length
    json_response.each do |record|
      assert record.values_at("symbol", "exchange", "name", "date", "type", "iex_id", "region", "currency", "isin").all?
    end
    assert_equal ['IEX_485A304E42592D52', 'IEX_4A4B355446472D52'], json_response.map{ |record| record["iex_id"]}
  end

  test "GET /search returns symbols when partial isin is passed as search term" do
    isin = 'DE00098'

    get "/v1/search", params: {q: isin}, headers: {"Accept" => 'application/json' }

    assert_response :ok
    json_response = @response.parsed_body
    assert 2, json_response.length
    json_response.each do |record|
      assert record.values_at("symbol", "exchange", "name", "date", "type", "iex_id", "region", "currency", "isin").all?
    end
    assert_equal ['IEX_485A304E42592D52', 'IEX_4A4B355446472D52'], json_response.map{ |record| record["iex_id"]}
  end

  test "GET /search returns 404 Not Found if no symbol is found" do
    get "/v1/search", params: {q: "XXXXXX"}, headers: {"Accept" => 'application/json' }

    assert_response :not_found
    assert_equal 404, @response.parsed_body["status"]
    assert_equal "not_found", @response.parsed_body["message"]
  end

  test "GET /search returns 400 Bad Request if search term is missing" do
    get "/v1/search", headers: {"Accept" => 'application/json' }

    assert_response :bad_request
    assert_equal 400, @response.parsed_body["status"]
    assert_equal "search_term_missing", @response.parsed_body["message"]
  end
end
