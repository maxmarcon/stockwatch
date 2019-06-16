require 'test_helper'

class FigiServiceTest < ActiveSupport::TestCase

  ISIN = "IE00B53SZB19"

  NEW_FIGI_RESPONSE = [
    {
      "data": [
        {
          "figi": "BBG000BMLLV4",
          "name": "MAINFIRST GERMAN FUND-A",
          "ticker": "MFGERMA",
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
          "name": "MAINFIRST GERMAN FUND-A",
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
  ]}]

  UPDATE_RESPONSE = [
    {
      "data": [
        {
          "figi": "BBG00LNBYMV3",
          "name": "MAINFIRST GERMAN FUND-A",
          "ticker": "MFGERMA",
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
  ]}]


  def setup
    @service = FigiService.new({"base_url" => "https://api.com"})
  end

  test "should fetch new FIGIs" do

    rest_response = Minitest::Mock.new
    rest_response.expect :body, NEW_FIGI_RESPONSE.to_json

    RestClient.stub :post, rest_response do

      figis = @service.get_by_isin([ISIN])
      figis.each do |figi|
        assert_equal ISIN, figi.isin
      end

      assert_equal ["BBG000BMLLV4", "BBG00332SS94"], figis.map(&:figi)
    end

    assert_equal 2, Figi.where(isin: ISIN).count
    assert rest_response.verify
  end


  test "should update out-of-date FIGI" do

    rest_response = Minitest::Mock.new
    rest_response.expect :body, UPDATE_RESPONSE.to_json
    isin = figis(:old_figi).isin

    RestClient.stub :post, rest_response do
      figis = @service.get_by_isin([isin])

      assert_equal 1, figis.count
      assert_equal UPDATE_RESPONSE[0][:data][0][:name], figis.first.name
      assert_equal UPDATE_RESPONSE[0][:data][0][:ticker], figis.first.ticker
    end

    assert UPDATE_RESPONSE[0][:data][0][:name], Figi.where(isin: isin).select('name')
    assert rest_response.verify
  end


  test "should not update fresh FIGI" do

    isin = figis(:new_figi).isin
    figis = @service.get_by_isin([isin])

    assert_equal 1, figis.count
    assert_equal figis(:new_figi), figis.first
  end
end
