require "test_helper"

class AchievementEvaluatorTest < ActiveSupport::TestCase
  def setup
    SeedLoader.call
    @tournament = Tournament.current
    @user = User.create!(username: "evaltester")
    @quiniela = @user.quinielas.create!(tournament: @tournament)
  end

  test "awards Profeta at 5 exact hits and returns it once" do
    @quiniela.update!(exact_hits: 5)
    newly = AchievementEvaluator.new(@quiniela, current_rank: 1).call
    assert_equal ["profeta"], newly.map(&:key)
    assert @quiniela.achievements.exists?(key: "profeta")

    again = AchievementEvaluator.new(@quiniela, current_rank: 1).call
    assert_empty again # not earned twice
  end

  test "does not award Profeta below 5 exact hits" do
    @quiniela.update!(exact_hits: 4)
    newly = AchievementEvaluator.new(@quiniela, current_rank: 1).call
    assert_not (newly.map(&:key).include?("profeta"))
  end

  test "awards Remontada after climbing 10+ places and tracks worst_rank" do
    AchievementEvaluator.new(@quiniela, current_rank: 15).call
    assert_equal 15, @quiniela.reload.worst_rank
    assert_not @quiniela.achievements.exists?(key: "remontada")

    newly = AchievementEvaluator.new(@quiniela, current_rank: 5).call # climbed 10
    assert_includes newly.map(&:key), "remontada"
  end
end
