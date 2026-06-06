require "test_helper"

class QuinielasHelperTest < ActionView::TestCase
  def setup
    SeedLoader.call
    @tournament = Tournament.current
    @user = User.create!(username: "predtester")
    @quiniela = @user.quinielas.create!(tournament: @tournament)
  end

  # Fill all three phases so the quiniela is a complete "first part".
  def complete!
    @tournament.groups.each do |g|
      t = g.teams.to_a
      @quiniela.group_predictions.create!(
        group: g, first_team: t[0], second_team: t[1], third_team: t[2], fourth_team: t[3]
      )
    end
    @quiniela.update!(best_third_groups: %w[A B C D E F G H])
    player = Player.first
    team = Team.first
    @quiniela.create_award_prediction!(
      balon_oro_player: player, bota_oro_player: player, guante_oro_player: player,
      young_player: player, fair_play_team: team
    )
    @quiniela.reload
  end

  test "prediction_card_data returns the full shape when complete" do
    complete!
    data = prediction_card_data(@quiniela)

    assert_equal "MI PREDICCIÓN", data[:title]
    assert_equal @user.display_name, data[:username]
    assert data.key?(:userFlag)

    assert_equal @tournament.groups.count, data[:groups].size
    g = data[:groups].first
    assert g[:name].present?
    assert g[:first][:name].present?
    assert g[:first].key?(:flag)
    assert g[:second][:name].present?

    assert_equal 8, data[:thirds].size
    assert data[:thirds].first[:name].present?
    assert data[:thirds].first.key?(:flag)

    assert_equal 5, data[:awards].size
    assert_equal "Balón de Oro", data[:awards].first[:label]
    assert data[:awards].first[:name].present?
    assert data[:awards].first.key?(:flag)
    assert_equal "Fair Play", data[:awards].last[:label]
  end

  test "achievements_card_data lists only unlocked achievements" do
    @quiniela.achievements.create!(key: "profeta", earned_at: Time.current)
    data = achievements_card_data(@quiniela)

    assert_equal "MIS LOGROS", data[:title]
    assert_equal @user.display_name, data[:username]
    assert_equal AchievementCatalog::ALL.size, data[:total]
    assert_equal 1, data[:count]
    assert_equal [ "Profeta" ], data[:achievements].map { |a| a[:name] }
    assert data[:achievements].first[:emoji].present?
    assert data[:achievements].first[:description].present?
  end

  test "achievements_card_data is empty when nothing is unlocked" do
    data = achievements_card_data(@quiniela)
    assert_equal 0, data[:count]
    assert_empty data[:achievements]
  end

  test "teams_dataset is cached per tournament and reused" do
    first = teams_dataset(@tournament)
    Team.update_all(name: "ZZZ")                      # change the DB underneath
    assert_equal first, teams_dataset(@tournament)    # served from cache, not rebuilt
    Rails.cache.clear
    refute_equal first, teams_dataset(@tournament)    # rebuilt after the cache clears
  end

  test "players_dataset is cached per tournament and reused" do
    first = players_dataset(@tournament)
    Player.update_all(name: "ZZZ")
    assert_equal first, players_dataset(@tournament)  # served from cache
    Rails.cache.clear
    refute_equal first, players_dataset(@tournament)  # rebuilt after clear
  end

  test "thirds_payload is cached per tournament and reused" do
    first = thirds_payload(@tournament)
    Team.update_all(name: "ZZZ")
    assert_equal first, thirds_payload(@tournament)   # served from cache
    Rails.cache.clear
    refute_equal first, thirds_payload(@tournament)   # rebuilt after clear
  end

  test "prediction_card_data degrades gracefully when empty" do
    data = prediction_card_data(@quiniela)

    assert_equal @tournament.groups.count, data[:groups].size
    assert_nil data[:groups].first[:first]
    assert_empty data[:thirds]
    assert_empty data[:awards]
  end
end
