require 'test_helper'

class FigiServiceTest < ActiveSupport::TestCase

  NEW_FIGI_ISIN = "IE00B53SZB19"

  FRESH_FIGI_ISIN = "DE0005933972"

  OLD_FIGI_ISIN = "DE0005933973"

  ISINS = [NEW_FIGI_ISIN, FRESH_FIGI_ISIN, OLD_FIGI_ISIN]

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


  def setup
    @service = FigiService.new({"base_url" => "https://api.com"})
    @rest_correct_response = Minitest::Mock.new.expect :body, REST_CORRECT_RESPONSE.to_json
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
end
