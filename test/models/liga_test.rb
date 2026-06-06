require "test_helper"

class LigaTest < ActiveSupport::TestCase
  def setup
    @tournament = Tournament.create!(name: "WC", year: 2026)
    @creator = User.create!(username: "creator_fc")
  end

  def build_liga(attrs = {})
    Liga.new({ name: "Los amigos", max_players: 10, creator: @creator, tournament: @tournament }.merge(attrs))
  end

  test "valid liga generates a unique invite code on create" do
    liga = build_liga
    assert liga.save
    assert_equal Liga::CODE_LENGTH, liga.invite_code.length
    assert_match(/\A[#{Liga::CODE_ALPHABET.join}]+\z/, liga.invite_code)
  end

  test "requires a name" do
    assert_not build_liga(name: "").valid?
  end

  test "max_players within range" do
    assert_not build_liga(max_players: 1).valid?
    assert_not build_liga(max_players: 51).valid?
    assert build_liga(max_players: 2).valid?
    assert build_liga(max_players: 50).valid?
  end

  test "full? reflects membership count vs cupo" do
    liga = build_liga(max_players: 2)
    liga.save!
    liga.memberships.create!(user: @creator)
    assert_not liga.full?
    liga.memberships.create!(user: User.create!(username: "second_fc"))
    assert liga.full?
  end

  test "deletable_by? only the creator and only when alone" do
    liga = build_liga
    liga.save!
    liga.memberships.create!(user: @creator)
    other = User.create!(username: "other_fc")
    assert liga.deletable_by?(@creator)
    assert_not liga.deletable_by?(other)

    liga.memberships.create!(user: other)
    assert_not liga.deletable_by?(@creator), "no se puede borrar con otros miembros"
  end

  test "membership is unique per liga and user" do
    liga = build_liga
    liga.save!
    liga.memberships.create!(user: @creator)
    dup = liga.memberships.build(user: @creator)
    assert_not dup.valid?
  end

  test "destroying a liga removes its memberships" do
    liga = build_liga
    liga.save!
    liga.memberships.create!(user: @creator)
    assert_difference "LigaMembership.count", -1 do
      liga.destroy
    end
  end

  # Prize -----------------------------------------------------------------

  test "a liga without a prize is valid and has no pot" do
    liga = build_liga(has_prize: false, prize_pot: nil)
    assert liga.valid?
    assert_nil liga.prize_share(5)
  end

  test "con premio requires a positive integer pot" do
    assert_not build_liga(has_prize: true, prize_pot: nil).valid?
    assert_not build_liga(has_prize: true, prize_pot: 0).valid?
    assert_not build_liga(has_prize: true, prize_pot: -10).valid?
    assert build_liga(has_prize: true, prize_pot: 500_000).valid?
  end

  test "con premio rejects a pot that would overflow the integer column" do
    # Must fail as a validation error (422), not raise ActiveModel::RangeError at save (500).
    liga = build_liga(has_prize: true, prize_pot: 9_999_999_999)
    assert_not liga.valid?
    assert_nothing_raised { liga.save }
  end

  test "disabling the prize clears any pot before validation" do
    liga = build_liga(has_prize: false, prize_pot: 500_000)
    assert liga.valid?
    assert_nil liga.prize_pot
  end

  test "prize_share splits the pot evenly, rounded" do
    liga = build_liga(has_prize: true, prize_pot: 500_000)
    assert_equal 100_000, liga.prize_share(5)
    assert_equal 50_000, liga.prize_share(10)
  end

  test "prize_share rounds when the split is not exact and flags it" do
    liga = build_liga(has_prize: true, prize_pot: 100)
    assert_equal 33, liga.prize_share(3) # 33.33 -> 33
    assert_not liga.prize_share_exact?(3)
    assert liga.prize_share_exact?(4)
  end

  test "prize helpers are nil/false without a prize" do
    liga = build_liga(has_prize: false)
    assert_nil liga.prize_share(4)
    assert_not liga.prize_share_exact?(4)
  end
end
