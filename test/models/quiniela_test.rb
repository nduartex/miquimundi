require "test_helper"

class QuinielaTest < ActiveSupport::TestCase
  test "defaults counters to zero" do
    q = Quiniela.new
    assert_equal 0, q.total_points
    assert_equal 0, q.exact_hits
    assert_equal 0, q.match_hits
  end

  test "submitted? reflects submitted_at" do
    assert_not Quiniela.new.submitted?
    assert Quiniela.new(submitted_at: Time.current).submitted?
  end
end
