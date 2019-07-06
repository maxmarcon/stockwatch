require("test_helper")

class RouteTest < ActionController::TestCase

  test "/app routes to webapp controller" do
    assert_routing("/app", controller: "webapp", action: "home")
  end

  test "/500 routes to error#handle_internal_error" do
    assert_routing("/500", controller: "error", action: "handle_internal_error")
  end

  test "/404 routes to error#handle_not_found" do
    assert_routing("/404", controller: "error", action: "handle_not_found")
  end

  test "/400 routes to error#handle_bad_request" do
    assert_routing("/400", controller: "error", action: "handle_bad_request")
  end

  test "unknown route routes to error#handle_not_found" do
    assert_routing("/NONEXISTENT_ROUTE", controller: "error", action: "handle_not_found" , path: "NONEXISTENT_ROUTE")
  end
end
