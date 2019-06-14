require 'test_helper'

class WebappControllerTest < ActionDispatch::IntegrationTest
  test "should get home" do
    get webapp_home_url
    assert_response :success
  end

end
