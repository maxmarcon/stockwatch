require 'test_helper'

class ApiCallTest < ActiveSupport::TestCase

  NEW_DIGEST = "NEW_DIGEST"

  test "#called? return true for recent call" do
    call = api_calls(:recent_call)

    assert ApiCall.called?(:iex, call.call_digest, 1.day)
  end

  test "#called? return false for old call" do
    call = api_calls(:old_call)

    assert_not ApiCall.called?(:iex, call.call_digest, 1.day)
  end

  test "#called? return true for old call if no time period is given" do
    call = api_calls(:old_call)

    assert ApiCall.called?(:iex, call.call_digest)
  end

  test "#called? return false for new call" do
    assert_not ApiCall.called?(:iex, NEW_DIGEST, 1.day)
  end

  test "#record_call records new call" do

    ApiCall.record_call(:iex, NEW_DIGEST)

    assert ApiCall.where(call_digest: NEW_DIGEST).exists?
    assert ApiCall.called?(:iex, NEW_DIGEST, 1.day)
  end

  test "#record_call refresh old call" do

    call = api_calls(:old_call)

    assert_not ApiCall.called?(:iex, call.call_digest, 1.day)

    ApiCall.record_call(:iex, call.call_digest)

    assert ApiCall.called?(:iex, call.call_digest, 1.day)
  end
end
