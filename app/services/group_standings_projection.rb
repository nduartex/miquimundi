# Builds a group table for display. With nothing to overlay it returns the
# official GroupStanding rows in ESPN's rank order (which carries the fine
# tiebreakers we can't reproduce). When a group has a match in progress — or one
# that just finished but ESPN's table hasn't counted yet (its /standings lags the
# scoreboard at full time) — it projects that result on top: adds the goals/points
# and re-sorts by the basic FIFA criteria (points, goal difference, goals scored)
# so users see how the group *would* stand right now. A finished match is bridged
# only until the official `played` reflects it, so it's never counted twice.
class GroupStandingsProjection
  Row = Struct.new(:team, :played, :wins, :draws, :losses, :goals_for,
                   :goals_against, :goal_difference, :points, :rank, :live,
                   keyword_init: true) do
    def live? = live
  end

  def self.call(group, live_matches: [])
    new(group, live_matches).rows
  end

  def initialize(group, matches)
    @group = group
    candidates = matches.select { |m| m.home_team&.group_id == group.id && m.home_goals && m.away_goals }
    @overlay = select_overlay(candidates)
  end

  def rows
    base = @group.group_standings.index_by(&:team_id)
    rows = @group.teams.map { |team| row_for(team, base[team.id]) }
    by_team = rows.index_by { |r| r.team.id }

    @overlay.each do |m|
      home_goals, away_goals = m.display_home_goals, m.display_away_goals
      live = m.live_now?
      apply_match(by_team[m.home_team_id], home_goals, away_goals, live)
      apply_match(by_team[m.away_team_id], away_goals, home_goals, live)
    end

    if @overlay.any?
      rows.sort_by! { |r| [ -r.points, -r.goal_difference, -r.goals_for, r.team.name ] }
      rows.each_with_index { |r, i| r.rank = i + 1 }
      rows
    else
      rows.sort_by { |r| r.rank || 99 }
    end
  end

  private

  # Live matches are always overlaid (ESPN never counts them until FT). Finished
  # matches are bridged only while ESPN's official table hasn't caught up: per
  # team the official `played` should already include each of its finished
  # matches, so we overlay a finished match only when both teams still have an
  # uncounted one (a positive deficit), decrementing as we go to avoid double
  # counting. Newest first so a (practically impossible) pair of simultaneous
  # uncounted FTs attributes to the most recent.
  def select_overlay(candidates)
    live, rest = candidates.partition(&:live_now?)
    finished = rest.select(&:finished?)
    return live if finished.empty?

    official = @group.group_standings.to_h { |s| [ s.team_id, s.played.to_i ] }
    deficit = Hash.new(0)
    finished.each { |m| deficit[m.home_team_id] += 1; deficit[m.away_team_id] += 1 }
    deficit.each_key { |team_id| deficit[team_id] -= official.fetch(team_id, 0) }

    pending = finished.sort_by { |m| m.kickoff_at || Time.zone.at(0) }.reverse.select do |m|
      next false unless deficit[m.home_team_id] > 0 && deficit[m.away_team_id] > 0
      deficit[m.home_team_id] -= 1
      deficit[m.away_team_id] -= 1
      true
    end
    live + pending
  end

  def row_for(team, standing)
    Row.new(
      team: team,
      played: standing&.played.to_i, wins: standing&.wins.to_i,
      draws: standing&.draws.to_i, losses: standing&.losses.to_i,
      goals_for: standing&.goals_for.to_i, goals_against: standing&.goals_against.to_i,
      goal_difference: standing&.goal_difference.to_i, points: standing&.points.to_i,
      rank: standing&.rank, live: false
    )
  end

  # Overlays one match result. Only a genuinely in-progress match flags the row
  # as live (drives the "En vivo" banner / auto-refresh). A finished match we're
  # bridging until ESPN's official table catches up corrects the numbers without
  # pretending it's still being played.
  def apply_match(row, scored, conceded, live)
    return if row.nil?
    row.live ||= live
    row.played += 1
    row.goals_for += scored
    row.goals_against += conceded
    row.goal_difference = row.goals_for - row.goals_against
    if scored > conceded
      row.wins += 1
      row.points += 3
    elsif scored < conceded
      row.losses += 1
    else
      row.draws += 1
      row.points += 1
    end
  end
end
