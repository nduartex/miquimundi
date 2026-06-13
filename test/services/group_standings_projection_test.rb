require "test_helper"

class GroupStandingsProjectionTest < ActiveSupport::TestCase
  def setup
    @tournament = Tournament.create!(name: "WC", year: 2026)
    @group = Group.create!(tournament: @tournament, name: "A")
    @t1 = Team.create!(group: @group, name: "Alfa", code: "AAA")
    @t2 = Team.create!(group: @group, name: "Beta", code: "BBB")
    @t3 = Team.create!(group: @group, name: "Gama", code: "CCC")
    @t4 = Team.create!(group: @group, name: "Delta", code: "DDD")
  end

  def standing(team, rank:, played: 0, points: 0, gf: 0, ga: 0)
    GroupStanding.create!(group: @group, team: team, rank: rank, played: played,
                          points: points, goals_for: gf, goals_against: ga,
                          goal_difference: gf - ga)
  end

  def live_match(home, away, hg, ag)
    Match.create!(tournament: @tournament, phase: "group", home_team: home, away_team: away,
                  status: "live", home_goals: hg, away_goals: ag, kickoff_at: 1.hour.ago)
  end

  test "without live matches it returns rows in official rank order" do
    standing(@t2, rank: 1, played: 1, points: 3)
    standing(@t1, rank: 2, played: 1, points: 1)
    standing(@t3, rank: 3, played: 1, points: 1)
    standing(@t4, rank: 4, played: 1, points: 0)

    rows = GroupStandingsProjection.call(@group, live_matches: [])
    assert_equal [@t2, @t1, @t3, @t4].map(&:code), rows.map { |r| r.team.code }
    assert rows.none?(&:live?)
  end

  test "projects an in-progress match on top of the official table and re-sorts" do
    # Matchday 1 done: everyone level on 0 except nobody played yet here.
    standing(@t1, rank: 1, played: 0)
    standing(@t2, rank: 2, played: 0)
    standing(@t3, rank: 3, played: 0)
    standing(@t4, rank: 4, played: 0)
    match = live_match(@t1, @t2, 2, 0) # t1 winning live

    rows = GroupStandingsProjection.call(@group, live_matches: [match])
    leader = rows.first
    assert_equal @t1.code, leader.team.code
    assert_equal 3, leader.points
    assert_equal 1, leader.played
    assert_equal 2, leader.goal_difference
    assert leader.live?

    loser = rows.find { |r| r.team == @t2 }
    assert_equal 4, loser.rank
    assert loser.live?
    assert_not rows.find { |r| r.team == @t3 }.live?
  end

  test "live draw awards a point to both sides" do
    [@t1, @t2, @t3, @t4].each_with_index { |t, i| standing(t, rank: i + 1) }
    match = live_match(@t1, @t2, 1, 1)

    rows = GroupStandingsProjection.call(@group, live_matches: [match])
    assert_equal 1, rows.find { |r| r.team == @t1 }.points
    assert_equal 1, rows.find { |r| r.team == @t2 }.points
  end

  test "ignores live matches from other groups and those without a score yet" do
    other = Group.create!(tournament: @tournament, name: "B")
    ot = Team.create!(group: other, name: "Omega", code: "OOO")
    standing(@t1, rank: 1)
    foreign = Match.create!(tournament: @tournament, phase: "group", home_team: ot,
                            away_team: Team.create!(group: other, name: "Psi", code: "PPP"),
                            status: "live", home_goals: 3, away_goals: 0, kickoff_at: 1.hour.ago)
    no_score = Match.create!(tournament: @tournament, phase: "group", home_team: @t1,
                             away_team: @t2, status: "live", kickoff_at: 1.hour.ago)

    rows = GroupStandingsProjection.call(@group, live_matches: [foreign, no_score])
    assert rows.none?(&:live?), "no projectable live match for this group"
  end
end
