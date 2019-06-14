require("test_helper")

class RouteTest < ActionController::TestCase

  def test_app_should_route_to_web_app_home
    assert_routing("/app", :controller => "webapp", :action => "home")
  end
end
