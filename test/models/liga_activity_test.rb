require "test_helper"

class LigaActivityTest < ActiveSupport::TestCase
  def setup
    @tournament = Tournament.create!(name: "WC", year: 2026)
    @creator = User.create!(username: "creator_fc")
    @liga = Liga.create!(name: "Los amigos", max_players: 10, creator: @creator, tournament: @tournament)
  end

  test "valid with a listed action and metadata" do
    activity = @liga.activities.build(user: @creator, action: "joined", metadata: { actor_name: "Cris" })
    assert activity.valid?
  end

  test "invalid with an unknown action" do
    assert_not @liga.activities.build(action: "hacked").valid?
    assert_not @liga.activities.build(action: "").valid?
  end

  test "requires a liga but the user is optional" do
    assert_not LigaActivity.new(action: "joined").valid?
    assert @liga.activities.build(action: "joined", user: nil).valid?
  end

  test "recent orders newest first" do
    old = @liga.activities.create!(action: "created", created_at: 2.days.ago)
    new = @liga.activities.create!(action: "joined")
    assert_equal [ new, old ], @liga.activities.recent.to_a
  end

  test "destroying a liga deletes its activities" do
    @liga.activities.create!(action: "created")
    @liga.activities.create!(action: "joined")
    assert_difference "LigaActivity.count", -2 do
      @liga.destroy
    end
  end
end
