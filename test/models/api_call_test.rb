require 'test_helper'

class ApiCallTest < ActiveSupport::TestCase

  NEW_DIGEST = "NEW_DIGEST"

  BLOCK = ->{ :ok }
  RAISING_BLOCK = ->{ raise "api call failed" }

  test "#atomic_api_call doesn't run block for recent call" do
    call = api_calls(:recent_call)
    called_at = call.called_at

    assert_equal [false, :called_recently], ApiCall.atomic_api_call(:iex, call.call_digest, 1.day, &BLOCK)

    assert_equal called_at, call.reload.called_at
  end

  test "#atomic_api_call runs block for recent call if max_age is nil" do
    call = api_calls(:recent_call)
    called_at = call.called_at

    assert_equal [true, :ok], ApiCall.atomic_api_call(:iex, call.call_digest, nil, &BLOCK)

    call.reload

    assert call.called_at > called_at
  end

  test "#atomic_api_call runs block for old call" do
    call = api_calls(:old_call)
    called_at = call.called_at

    assert_equal [true, :ok], ApiCall.atomic_api_call(:iex, call.call_digest, 1.day, &BLOCK)

    call.reload

    assert call.called_at > called_at
  end

  test "#atomic_api_call runs block for dangling call" do
    call = api_calls(:dangling_call)
    assert_nil call.called_at

    assert_equal [true, :ok], ApiCall.atomic_api_call(:iex, call.call_digest, 1.day, &BLOCK)

    call.reload

    assert call.called_at
  end

  test "#atomic_api_call runs block for new call" do

    assert_equal [true, :ok], ApiCall.atomic_api_call(:iex, NEW_DIGEST, 1.day, &BLOCK)

    call = ApiCall.find_by(api: :iex, call_digest: NEW_DIGEST)

    assert call
    assert call.called_at
  end

  test "#atomic_api_call raises if no block is given" do

    e = assert_raises RuntimeError do
      ApiCall.atomic_api_call(:iex, NEW_DIGEST, 1.day)
    end

    assert_equal "You need to pass a block", e.message
  end

  test "#atomic_api_call leaves dangling new call when block raises" do
    assert_raises RuntimeError do
      ApiCall.atomic_api_call(:iex, NEW_DIGEST, 1.day, &RAISING_BLOCK)
    end

    call = ApiCall.find_by(api: :iex, call_digest: NEW_DIGEST)

    assert call
    assert_nil call.called_at
  end

  test "#atomic_api_call with old call does not update call when block reaises" do
    call = api_calls(:old_call)
    called_at = call.called_at

    assert_raises RuntimeError do
      ApiCall.atomic_api_call(:iex, call.call_digest, 1.day, &RAISING_BLOCK)
    end

    call.reload

    assert_equal call.called_at, called_at
  end
end
