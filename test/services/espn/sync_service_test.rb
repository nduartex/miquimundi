require "test_helper"

module Espn
  class SyncServiceTest < ActiveSupport::TestCase
    include ActiveJob::TestHelper

    # Duck-typed Espn::Client: tests feed it parsed payloads, no HTTP involved.
    class FakeClient
      attr_accessor :scoreboard_payload, :summary_payloads, :standings_payload

      def initialize
        @scoreboard_payload = { "events" => [] }
        @summary_payloads = {}
        @standings_payload = { "children" => [] }
      end

      def scoreboard(dates:) = @scoreboard_payload
      def summary(event_id) = @summary_payloads.fetch(event_id, { "keyEvents" => [] })
      def standings(season: 2026) = @standings_payload
    end

    def setup
      @tournament = Tournament.create!(name: "WC", year: 2026)
      @group = Group.create!(tournament: @tournament, name: "A")
      @t1 = Team.create!(group: @group, name: "Alfa", code: "AAA")
      @t2 = Team.create!(group: @group, name: "Beta", code: "BBB")
      @t3 = Team.create!(group: @group, name: "Gama", code: "CCC")
      @t4 = Team.create!(group: @group, name: "Delta", code: "DDD")
      @client = FakeClient.new
      @service = SyncService.new(@tournament, client: @client)
    end

    def event(id:, home:, away:, state:, hs: nil, as: nil, date: "2026-06-13T19:00Z",
              home_shootout: nil, away_shootout: nil)
      competitor = lambda do |team, side, score, shootout|
        c = { "homeAway" => side, "score" => score&.to_s,
              "team" => { "id" => "espn-#{team.id}", "abbreviation" => team.code, "displayName" => team.name } }
        c["shootoutScore"] = shootout.to_s if shootout
        c
      end
      { "id" => id, "date" => date,
        "competitions" => [ {
          "status" => { "type" => { "state" => state, "completed" => state == "post" } },
          "competitors" => [ competitor.call(home, "home", hs, home_shootout),
                            competitor.call(away, "away", as, away_shootout) ]
        } ] }
    end

    def goal_event(team:, player:, minute:, type: "Goal", shootout: false)
      { "scoringPlay" => true, "shootout" => shootout,
        "type" => { "text" => type },
        "clock" => { "displayValue" => minute },
        "team" => { "id" => team.reload.espn_id },
        "participants" => [ { "athlete" => { "displayName" => player } } ] }
    end

    def standings_for(group_name, rows, played: 1)
      entries = rows.map do |team, rank, points, gd, gf|
        { "team" => { "id" => team.reload.espn_id || "espn-#{team.id}", "abbreviation" => team.code },
          "stats" => [
            { "name" => "rank", "value" => rank }, { "name" => "points", "value" => points },
            { "name" => "pointDifferential", "value" => gd }, { "name" => "pointsFor", "value" => gf },
            { "name" => "gamesPlayed", "value" => played }, { "name" => "wins", "value" => 0 },
            { "name" => "ties", "value" => 0 }, { "name" => "losses", "value" => 0 },
            { "name" => "pointsAgainst", "value" => 0 }
          ] }
      end
      { "name" => "Group #{group_name}", "standings" => { "entries" => entries } }
    end

    test "creates a group match from the scoreboard and stores espn ids" do
      @client.scoreboard_payload = { "events" => [ event(id: "100", home: @t1, away: @t2, state: "pre") ] }
      assert_difference "Match.count", 1 do
        @service.sync!
      end
      match = Match.find_by(espn_id: "100")
      assert_equal "group", match.phase
      assert_equal "scheduled", match.status
      assert_equal @t1, match.home_team
      assert_nil match.home_goals, "pre-match events must not write scores"
      assert_equal "espn-#{@t1.id}", @t1.reload.espn_id
    end

    test "live match updates score and goal events" do
      [ @t1, @t2 ].each { |t| t.update!(espn_id: "espn-#{t.id}") }
      @client.scoreboard_payload = { "events" => [ event(id: "100", home: @t1, away: @t2, state: "in", hs: 1, as: 0) ] }
      @client.summary_payloads["100"] = { "keyEvents" => [
        goal_event(team: @t1, player: "Juan Pérez", minute: "9'"),
        { "scoringPlay" => false, "type" => { "text" => "Yellow Card" } }
      ] }
      @service.sync!
      match = Match.find_by(espn_id: "100")
      assert_equal "live", match.status
      assert_equal [ 1, 0 ], [ match.home_goals, match.away_goals ]
      assert_equal [ "Juan Pérez" ], match.goals.pluck(:player_name)
    end

    test "goal parsing flags penalties and own goals and links roster players" do
      [ @t1, @t2 ].each { |t| t.update!(espn_id: "espn-#{t.id}") }
      player = Player.create!(team: @t1, name: "Julián Quiñones")
      @client.scoreboard_payload = { "events" => [ event(id: "100", home: @t1, away: @t2, state: "post", hs: 2, as: 0) ] }
      @client.summary_payloads["100"] = { "keyEvents" => [
        goal_event(team: @t1, player: "Julian Quinones", minute: "9'"),
        goal_event(team: @t1, player: "Rival Uno", minute: "50'", type: "Own Goal"),
        goal_event(team: @t1, player: "Nadie", minute: "120'", shootout: true)
      ] }
      @service.sync!
      goals = Match.find_by(espn_id: "100").goals.in_order
      assert_equal 2, goals.size, "shootout kicks are not goals"
      assert_equal player, goals.first.player, "accent-insensitive roster link"
      assert goals.last.own_goal
    end

    test "a group-stage FT alone never triggers a recalculation" do
      @client.scoreboard_payload = { "events" => [ event(id: "100", home: @t1, away: @t2, state: "post", hs: 1, as: 0) ] }
      @client.standings_payload = { "children" => [ standings_for("A", [ [ @t1, 1, 3, 1, 1 ], [ @t2, 2, 0, -1, 0 ], [ @t3, 3, 0, 0, 0 ], [ @t4, 4, 0, 0, 0 ] ]) ] }
      assert_no_enqueued_jobs only: RecalculateScoresJob do
        @service.sync!
      end
      assert_equal 0, GroupResult.count
    end

    test "completing a group creates its GroupResult from ESPN ranks and recalculates" do
      # 5 of 6 matches already finished (0-0 so goal rows trivially add up).
      pairs = [ [ @t1, @t3 ], [ @t1, @t4 ], [ @t2, @t3 ], [ @t2, @t4 ], [ @t3, @t4 ] ]
      pairs.each_with_index do |(h, a), i|
        Match.create!(tournament: @tournament, phase: "group", home_team: h, away_team: a,
                      status: "finished", home_goals: 0, away_goals: 0, espn_id: "done-#{i}",
                      kickoff_at: 2.days.ago)
      end
      @client.scoreboard_payload = { "events" => [ event(id: "100", home: @t1, away: @t2, state: "post", hs: 1, as: 0) ] }
      @client.summary_payloads["100"] = { "keyEvents" => [ goal_event(team: @t1, player: "Juan", minute: "9'") ] }
      @client.standings_payload = { "children" => [ standings_for("A", [ [ @t1, 1, 9, 5, 5 ], [ @t2, 2, 4, 1, 2 ], [ @t3, 3, 2, -2, 1 ], [ @t4, 4, 1, -4, 0 ] ], played: 3) ] }

      assert_enqueued_with(job: RecalculateScoresJob, args: [ @tournament.id ]) do
        @service.sync!
      end
      result = @group.reload.group_result
      assert_equal [ @t1.id, @t2.id ], [ result.first_team_id, result.second_team_id ]
    end

    test "stale standings (played < 3) block GroupResult creation even with all matches FT" do
      pairs = [ [ @t1, @t3 ], [ @t1, @t4 ], [ @t2, @t3 ], [ @t2, @t4 ], [ @t3, @t4 ] ]
      pairs.each_with_index do |(h, a), i|
        Match.create!(tournament: @tournament, phase: "group", home_team: h, away_team: a,
                      status: "finished", home_goals: 0, away_goals: 0, espn_id: "done-#{i}",
                      kickoff_at: 2.days.ago)
      end
      @client.scoreboard_payload = { "events" => [ event(id: "100", home: @t1, away: @t2, state: "post", hs: 1, as: 0) ] }
      # Standings lagging: ranks exist but only reflect 2 matchdays.
      @client.standings_payload = { "children" => [ standings_for("A", [ [ @t2, 1, 6, 3, 3 ], [ @t1, 2, 4, 1, 2 ], [ @t3, 3, 2, -2, 1 ], [ @t4, 4, 1, -2, 0 ] ], played: 2) ] }

      assert_no_enqueued_jobs only: RecalculateScoresJob do
        @service.sync!
      end
      assert_nil @group.reload.group_result, "stale ranks must not lock in qualifiers"
    end

    test "abandoned match (post, not completed) goes back to scheduled instead of sticking live" do
      Match.create!(tournament: @tournament, phase: "group", home_team: @t1, away_team: @t2,
                    status: "live", espn_id: "100", home_goals: 1, away_goals: 0, kickoff_at: 1.hour.ago)
      payload = event(id: "100", home: @t1, away: @t2, state: "post", hs: 1, as: 0)
      payload["competitions"][0]["status"]["type"]["completed"] = false
      @client.scoreboard_payload = { "events" => [ payload ] }
      @service.sync!
      assert_equal "scheduled", Match.find_by(espn_id: "100").status
    end

    test "sync_goals is a no-op when the fetched goals match what is stored" do
      [ @t1, @t2 ].each { |t| t.update!(espn_id: "espn-#{t.id}") }
      match = Match.create!(tournament: @tournament, phase: "group", home_team: @t1, away_team: @t2,
                            status: "live", espn_id: "100", kickoff_at: 1.hour.ago)
      goal = match.goals.create!(team: @t1, player_name: "Juan Pérez", minute: "9'", sort_order: 0)
      @client.summary_payloads["100"] = { "keyEvents" => [ goal_event(team: @t1, player: "Juan Pérez", minute: "9'") ] }
      @service.send(:sync_goals, match)
      assert_equal goal.id, match.goals.in_order.first.id, "identical goals must not be rewritten"
    end

    test "a new goal on a live match enqueues a Discord alert" do
      [ @t1, @t2 ].each { |t| t.update!(espn_id: "espn-#{t.id}") }
      match = Match.create!(tournament: @tournament, phase: "group", home_team: @t1, away_team: @t2,
                            status: "live", espn_id: "100", home_goals: 1, away_goals: 0, kickoff_at: 1.hour.ago)
      @client.summary_payloads["100"] = { "keyEvents" => [ goal_event(team: @t1, player: "Juan", minute: "9'") ] }
      assert_enqueued_with(job: Discord::DeliverJob) do
        @service.send(:sync_goals, match)
      end
    end

    test "only the brand new goal is announced, not the ones already stored" do
      [ @t1, @t2 ].each { |t| t.update!(espn_id: "espn-#{t.id}") }
      match = Match.create!(tournament: @tournament, phase: "group", home_team: @t1, away_team: @t2,
                            status: "live", espn_id: "100", home_goals: 1, away_goals: 1, kickoff_at: 1.hour.ago)
      match.goals.create!(team: @t1, player_name: "Juan", minute: "9'", sort_order: 0)
      @client.summary_payloads["100"] = { "keyEvents" => [
        goal_event(team: @t1, player: "Juan", minute: "9'"),
        goal_event(team: @t2, player: "Pedro", minute: "55'")
      ] }
      assert_enqueued_jobs 1, only: Discord::DeliverJob do
        @service.send(:sync_goals, match)
      end
    end

    test "finished-match backfill stores goals without announcing them" do
      [ @t1, @t2 ].each { |t| t.update!(espn_id: "espn-#{t.id}") }
      match = Match.create!(tournament: @tournament, phase: "group", home_team: @t1, away_team: @t2,
                            status: "finished", espn_id: "100", home_goals: 2, away_goals: 0, kickoff_at: 1.hour.ago)
      @client.summary_payloads["100"] = { "keyEvents" => [
        goal_event(team: @t1, player: "Juan", minute: "9'"),
        goal_event(team: @t1, player: "Pedro", minute: "55'")
      ] }
      assert_no_enqueued_jobs only: Discord::DeliverJob do
        @service.send(:sync_goals, match)
      end
      assert_equal 2, match.goals.count
    end

    test "first sight of a live match with several goals seeds a baseline silently" do
      [ @t1, @t2 ].each { |t| t.update!(espn_id: "espn-#{t.id}") }
      match = Match.create!(tournament: @tournament, phase: "group", home_team: @t1, away_team: @t2,
                            status: "live", espn_id: "100", home_goals: 2, away_goals: 0, kickoff_at: 1.hour.ago)
      @client.summary_payloads["100"] = { "keyEvents" => [
        goal_event(team: @t1, player: "Juan", minute: "9'"),
        goal_event(team: @t1, player: "Pedro", minute: "55'")
      ] }
      assert_no_enqueued_jobs only: Discord::DeliverJob do
        @service.send(:sync_goals, match)
      end
      assert_equal 2, match.goals.count, "goals are stored, just not replayed to Discord"
    end

    test "knockout FT maps by teams, records shootout winner and recalculates" do
      group_b = Group.create!(tournament: @tournament, name: "B")
      rival = Team.create!(group: group_b, name: "Omega", code: "OOO")
      ko = Match.create!(tournament: @tournament, phase: "round_32", bracket_slot: "R32-1",
                         home_team: @t1, away_team: rival, status: "scheduled")
      @client.scoreboard_payload = { "events" => [
        event(id: "900", home: rival, away: @t1, state: "post", hs: 1, as: 1,
              home_shootout: 4, away_shootout: 3)
      ] }
      assert_enqueued_with(job: RecalculateScoresJob) do
        @service.sync!
      end
      ko.reload
      assert_equal "900", ko.espn_id
      # ESPN had the teams reversed: scores must land on our orientation.
      assert_equal [ 1, 1 ], [ ko.home_goals, ko.away_goals ]
      assert_equal rival.id, ko.penalty_winner_id
    end

    test "when every group has a result the best thirds resolve once" do
      letters = ("A".."L").to_a
      groups = { "A" => @group }
      letters.drop(1).each { |l| groups[l] = Group.create!(tournament: @tournament, name: l) }
      groups.each_with_index do |(letter, group), i|
        teams = letter == "A" ? [ @t1, @t2, @t3 ] : Array.new(3) { |j| Team.create!(group: group, name: "#{letter}#{j}", code: "#{letter}#{j}X") }
        GroupResult.create!(group: group, first_team: teams[0], second_team: teams[1])
        # Third places with descending points: groups A..H qualify, I..L don't.
        GroupStanding.create!(group: group, team: teams[2], rank: 3, points: 12 - i,
                              goal_difference: 0, goals_for: 0)
      end

      assert_enqueued_with(job: RecalculateScoresJob) do
        @service.sync!
      end
      codes = @tournament.tournament_result.qualified_third_codes
      assert_equal 8, codes.size
      assert_includes codes, @t3.code
      assert_not_includes codes, GroupStanding.order(:points).first.team.code
    end
  end
end
