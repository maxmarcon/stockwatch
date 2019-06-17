require 'test_helper'

class FigiServiceTest < ActiveSupport::TestCase

  NEW_FIGI_ISIN = "IE00B53SZB19"

  FRESH_FIGI_ISIN = "DE0005933972"

  OLD_FIGI_ISIN = "DE0005933973"

  ISINS = [NEW_FIGI_ISIN, FRESH_FIGI_ISIN, OLD_FIGI_ISIN]

  REST_UNEXPECTED_FORMAT_RESPONSE = { "error": "serious" }

  REST_CORRECT_RESPONSE = [
    {
      "data": [
        # NEW_FIGI
        {
          "figi": "BBG000BMLLV4",
          "name": "MAINFIRST GERMAN FUND-A1",
          "ticker": "MFGERMA1",
          "exchCode": "LX",
          "compositeFIGI": "BBG000BMLLV4",
          "uniqueID": "EQ0000000007813300",
          "securityType": "Open-End Fund",
          "marketSector": "Equity",
          "shareClassFIGI": "BBG001SPMPB9",
          "uniqueIDFutOpt": nil,
          "securityType2": "Mutual Fund",
          "securityDescription": "MFGERMA"
        },
        {
          "figi": "BBG00332SS94",
          "name": "MAINFIRST GERMAN FUND-A2",
          "ticker": "MAM9",
          "exchCode": "GR",
          "compositeFIGI": "BBG00332SS94",
          "uniqueID": "EQ0000000024997775",
          "securityType": "Open-End Fund",
          "marketSector": "Equity",
          "shareClassFIGI": "BBG001SPMPB9",
          "uniqueIDFutOpt": nil,
          "securityType2": "Mutual Fund",
          "securityDescription": "MAM9"
        }
      ]
    },
    {
      "data": [
        # OLD_FIGI update
        {
          "figi": "BBG00LNBYMV3",
          "name": "MAINFIRST GERMAN FUND-A3",
          "ticker": "MFGERMA3",
          "exchCode": "LX",
          "compositeFIGI": "BBG000BMLLV4",
          "uniqueID": "EQ0000000007813300",
          "securityType": "Open-End Fund",
          "marketSector": "Equity",
          "shareClassFIGI": "BBG001SPMPB9",
          "uniqueIDFutOpt": nil,
          "securityType2": "Mutual Fund",
          "securityDescription": "MFGERMA"
        },
        {
          "figi": "BBG00LNBYMV5",
          "name": "MAINFIRST GERMAN FUND-A4",
          "ticker": "MFGERMA4",
          "exchCode": "LX",
          "compositeFIGI": "BBG000BMLLV4",
          "uniqueID": "EQ0000000007813300",
          "securityType": "Open-End Fund",
          "marketSector": "Equity",
          "shareClassFIGI": "BBG001SPMPB9",
          "uniqueIDFutOpt": nil,
          "securityType2": "Mutual Fund",
          "securityDescription": "MFGERMA"
        }
      ]
    }
  ]

  REST_RESPONSE_WITH_FIGI_ERRORS = [
    {
      "error": "An unexpected error occurred"
    },
    {
      "data": [
        # OLD_FIGI update
        {
          "figi": "BBG00LNBYMV3",
          "name": "MAINFIRST GERMAN FUND-A3",
          "ticker": "MFGERMA3",
          "exchCode": "LX",
          "compositeFIGI": "BBG000BMLLV4",
          "uniqueID": "EQ0000000007813300",
          "securityType": "Open-End Fund",
          "marketSector": "Equity",
          "shareClassFIGI": "BBG001SPMPB9",
          "uniqueIDFutOpt": nil,
          "securityType2": "Mutual Fund",
          "securityDescription": "MFGERMA"
        },
        {
          "figi": "BBG00LNBYMV5",
          "name": "MAINFIRST GERMAN FUND-A4",
          "ticker": "MFGERMA4",
          "exchCode": "LX",
          "compositeFIGI": "BBG000BMLLV4",
          "uniqueID": "EQ0000000007813300",
          "securityType": "Open-End Fund",
          "marketSector": "Equity",
          "shareClassFIGI": "BBG001SPMPB9",
          "uniqueIDFutOpt": nil,
          "securityType2": "Mutual Fund",
          "securityDescription": "MFGERMA"
        }
      ]
    }
  ]

  def setup
    @service = FigiService.new({"base_url" => "https://fake.api.com"})
    @rest_correct_response = Minitest::Mock.new.expect :body, REST_CORRECT_RESPONSE.to_json
    @rest_unexpected_format_response = Minitest::Mock.new.expect :body, REST_UNEXPECTED_FORMAT_RESPONSE.to_json
    @rest_malformed_response = Minitest::Mock.new.expect :body, "{NOT JSON"
    @rest_response_with_figi_errors = Minitest::Mock.new.expect :body, REST_RESPONSE_WITH_FIGI_ERRORS.to_json
  end

  test "should fetch new FIGIs" do

    RestClient.stub :post, @rest_correct_response do

      figis = @service.index_by_isin(ISINS)
      new_figis = figis[NEW_FIGI_ISIN]
      assert_equal 2, new_figis.count

      assert_equal REST_CORRECT_RESPONSE[0][:data].map{ |r| r[:figi] }, new_figis.map(&:figi)
      assert_equal REST_CORRECT_RESPONSE[0][:data].map{ |r| r[:name] }, new_figis.map(&:name)
      assert_equal REST_CORRECT_RESPONSE[0][:data].map{ |r| r[:ticker] }, new_figis.map(&:ticker)
    end

    assert @rest_correct_response.verify
    assert_equal 2, Figi.where(isin: NEW_FIGI_ISIN).count
  end


  test "should update expired FIGIs" do

    RestClient.stub :post, @rest_correct_response do
      figis = @service.index_by_isin(ISINS)
      old_figis = figis[OLD_FIGI_ISIN]

      assert_equal 2, old_figis.count

      assert_equal REST_CORRECT_RESPONSE[1][:data].map{ |r| r[:figi] }, old_figis.map(&:figi)
      assert_equal REST_CORRECT_RESPONSE[1][:data].map{ |r| r[:name] }, old_figis.map(&:name)
      assert_equal REST_CORRECT_RESPONSE[1][:data].map{ |r| r[:ticker] }, old_figis.map(&:ticker)
    end

    assert @rest_correct_response.verify
    assert_equal 2, Figi.where(isin: OLD_FIGI_ISIN).count
  end


  test "should not update fresh FIGIs" do

    RestClient.stub :post, @rest_correct_response do
      returned_figis = @service.index_by_isin(ISINS)
      fresh_figis = returned_figis[FRESH_FIGI_ISIN]

      assert_equal 2, fresh_figis.count
      assert_equal figis(:fresh_figi_1, :fresh_figi_2), fresh_figis
    end

    assert @rest_correct_response.verify
    assert_equal 2, Figi.where(isin: FRESH_FIGI_ISIN).count
  end

  test "can delete all FIGIs" do

    @service.delete_all

    assert_equal 0, Figi.count
  end

  test "can delete by ISIN" do

    isin = figis(:fresh_figi_1).isin
    other_isin = figis(:old_figi_1).isin

    @service.delete_by_isin([isin])

    assert_equal 0, Figi.where(isin: isin).count
    assert_equal 3, Figi.where.not(isin: isin).count
  end

  test "can handle errors from the FIGI API" do

    RestClient.stub :post, @rest_response_with_figi_errors do
      @service.index_by_isin(ISINS)
    end

    assert @rest_response_with_figi_errors.verify
    assert_equal 0, Figi.where(isin: NEW_FIGI_ISIN).count
  end

  test "raises if response has unexpected format" do

    RestClient.stub :post, @rest_unexpected_format_response do
      assert_raises RuntimeError do
        @service.index_by_isin(ISINS)
      end
    end
  end

  test "raises if response is invalid json" do

    RestClient.stub :post, @rest_malformed_response do
      assert_raises JSON::ParserError do
        @service.index_by_isin(ISINS)
      end
    end
  end
end
