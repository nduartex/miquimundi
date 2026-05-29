require "test_helper"

class RecalculateScoresJobTest < ActiveSupport::TestCase
  include ActionCable::TestHelper

  test "recomputes scores and broadcasts the ranking" do
    tournament = Tournament.create!(name: "WC", year: 2026)
    user = User.create!(email: "p@x.com")
    quiniela = Quiniela.create!(user: user, tournament: tournament, total_points: 999)

    assert_changes -> { quiniela.reload.total_points }, from: 999, to: 0 do
      assert_broadcasts("ranking_#{tournament.id}", 1) do
        RecalculateScoresJob.perform_now(tournament.id)
      end
    end
  end
end
