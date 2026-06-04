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
end
