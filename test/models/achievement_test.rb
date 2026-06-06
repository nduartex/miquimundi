require "test_helper"

class AchievementTest < ActiveSupport::TestCase
  def setup
    SeedLoader.call
    @tournament = Tournament.current
    @user = User.create!(username: "achiever")
    @quiniela = @user.quinielas.create!(tournament: @tournament)
  end

  test "a quiniela has many achievements" do
    @quiniela.achievements.create!(key: "profeta", earned_at: Time.current)
    assert_equal [ "profeta" ], @quiniela.reload.achievements.map(&:key)
  end

  test "the same achievement key cannot be earned twice by a quiniela" do
    @quiniela.achievements.create!(key: "profeta", earned_at: Time.current)
    assert_raises(ActiveRecord::RecordNotUnique) do
      @quiniela.achievements.create!(key: "profeta", earned_at: Time.current)
    end
  end
end
