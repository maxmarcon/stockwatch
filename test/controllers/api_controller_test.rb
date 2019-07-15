require 'test_helper'

class ApiControllerTest < ActionDispatch::IntegrationTest

  test "GET /isin retrieves mapping to symbol" do
    isin = 'DE0009848119'

    get "/v1/isin/#{isin}", headers: {"Accept" => 'application/json' }

    assert_response :success

    assert_equal 2, @response.parsed_body.count
    @response.parsed_body.each do |record|
      assert record.values_at("symbol", "exchange", "name", "date", "type", "iex_id", "region", "currency").all?
    end

    symbols = @response.parsed_body.map{ |record| record["symbol"] }
    assert symbols.include? '1SSEMYM1-MM'
    assert symbols.include? '1SSEMYMA2-MM'
  end

  test "GET /isin returns 404 Not Found with unknown ISIN" do
    isin = 'LU0767751091'

    get "/v1/isin/#{isin}", headers: {"Accept" => 'application/json' }

    assert_response :not_found

    assert_equal 404, @response.parsed_body["status"]
    assert_equal "not_found", @response.parsed_body["message"]
  end

  test "GET /isin returns 400 Bad Request with invalid ISIN" do
    isin = 'DE0009848119XXXX'

    get "/v1/isin/#{isin}", headers: {"Accept" => 'application/json' }

    assert_response :bad_request

    assert_equal 400, @response.parsed_body["status"]
    assert_equal "wrong_format", @response.parsed_body["message"]
  end

  test "GET /chart/:period returns the chart data by symbol" do
    symbol = '1SSEMYM1-MM'

    get "/v1/chart/1m", params: {symbol: symbol}, headers: {"Accept" => 'application/json' }

    assert_response :ok

    entries = @response.parsed_body
    assert_equal (1.month/1.day)*IexService::DAYS_THRESHOLD, entries.count
    entries.each do |record|
      assert record.values_at("date", "close", "volume", "change", "change_percent", "change_over_time").all?
    end
  end

  test "GET /chart/:period returns the chart data by iex_id" do
    iex_id = 'IEX_485A304E42592D52'

    get "/v1/chart/1m", params: {iex_id: iex_id}, headers: {"Accept" => 'application/json' }

    assert_response :ok

    entries = @response.parsed_body
    assert_equal (1.month/1.day)*IexService::DAYS_THRESHOLD, entries.count
    entries.each do |record|
      assert record.values_at("date", "close", "volume", "change", "change_percent", "change_over_time").all?
    end
  end

  test "GET /chart/:period returns 400 Bad Request with invalid period" do
    symbol = '1SSEMYM1-MM'

    get "/v1/chart/30m", params: {symbol: symbol}, headers: {"Accept" => 'application/json' }

    assert_response :bad_request

    assert_equal 400, @response.parsed_body["status"]
    assert_match "Invalid time period 30m", @response.parsed_body["message"]
  end

  test "GET /chart/:period returns 400 Bad Request if symbol is missing" do

    get "/v1/chart/1m", headers: {"Accept" => 'application/json' }

    assert_response :bad_request

    assert_equal 400, @response.parsed_body["status"]
    assert_match "You need to specify either a symbol or a iex_id", @response.parsed_body["message"]
  end

  test "GET /chart/:period returns 400 Bad Request with unknown iex_id" do
    iex_id = 'IEX_485A304E42592D53'

    get "/v1/chart/1m", params: {iex_id: iex_id}, headers: {"Accept" => 'application/json'}

    assert_response :bad_request

    assert_equal 400, @response.parsed_body["status"]
    assert_equal "ID #{iex_id} was not found", @response.parsed_body["message"]
  end
end
