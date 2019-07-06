require 'test_helper'

class ErrorControllerTest < ActionDispatch::IntegrationTest
  test "renders html internal error" do
    get '/500'

    assert_response :internal_server_error
    assert_select 'h1', 'An internal error has occurred - 500'
  end

  test "renders json internal error" do
    get '/500.json'

    assert_response :internal_server_error
    assert_equal({ 'status' => 500, 'message' => 'An internal error has occurred' }, response.parsed_body)
  end

  test "renders html internal error for unknown format" do
    get '/500.liquid'

    assert_response :internal_server_error
    assert_select 'h1', 'An internal error has occurred - 500'
  end

  test "renders html not found" do
    get '/404'

    assert_response :not_found
    assert_select 'h1', 'Not Found - 404'
  end

  test "renders json not foundr" do
    get '/404.json'

    assert_response :not_found
    assert_equal({ 'status' => 404, 'message' => 'Not Found' }, response.parsed_body)
  end

  test "renders html not found for unknown format" do
    get '/404.liquid'

    assert_response :not_found
    assert_select 'h1', 'Not Found - 404'
  end

  test "renders html bad request" do
    get '/400'

    assert_response :bad_request
    assert_select 'h1', 'Bad Request - 400'
  end

  test "renders json bad request" do
    get '/400.json'

    assert_response :bad_request
    assert_equal({ 'status' => 400, 'message' => 'Bad Request' }, response.parsed_body)
  end

  test "renders html bad request for unknown format" do
    get '/400.liquid'

    assert_response :bad_request
    assert_select 'h1', 'Bad Request - 400'
  end
end
