require 'test_helper'

class WebappControllerTest < ActionDispatch::IntegrationTest

  test "/ should redirect to /app" do
    get root_url
    assert_redirected_to app_path
  end

  test "/app should render webapp/home " do
    get app_url
    assert_response :success
    assert_template 'webapp/home'
  end
end
