require "test_helper"

class RankingsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @tournament = Tournament.create!(name: "WC", year: 2026)
    @u1 = User.create!(username: "ana", name: "Ana")
    @u2 = User.create!(username: "beto", name: "Beto")
    Quiniela.create!(user: @u1, tournament: @tournament, total_points: 30, exact_hits: 4, match_hits: 6)
    Quiniela.create!(user: @u2, tournament: @tournament, total_points: 50, exact_hits: 6, match_hits: 8)
  end

  test "ranked orders by points desc" do
    ranked = RankingsController.ranked(@tournament)
    assert_equal "Beto", ranked.first.user.name
  end

  test "index renders the leader first" do
    get rankings_path
    assert_response :success
    assert_match "Beto", response.body
  end
end
