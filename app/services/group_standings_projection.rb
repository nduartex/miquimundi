# Builds a group table for display. With no live match it returns the official
# GroupStanding rows in ESPN's rank order (which carries the fine tiebreakers we
# can't reproduce). When a group has a match in progress — ESPN's table doesn't
# count it until full time — it projects that result on top: adds the in-play
# goals/points and re-sorts by the basic FIFA criteria (points, goal
# difference, goals scored) so users see how the group *would* stand right now.
class GroupStandingsProjection
  Row = Struct.new(:team, :played, :wins, :draws, :losses, :goals_for,
                   :goals_against, :goal_difference, :points, :rank, :live,
                   keyword_init: true) do
    def live? = live
  end

  def self.call(group, live_matches: [])
    new(group, live_matches).rows
  end

  def initialize(group, live_matches)
    @group = group
    @live = live_matches.select { |m| m.home_team&.group_id == group.id && m.home_goals && m.away_goals }
  end

  def rows
    base = @group.group_standings.index_by(&:team_id)
    rows = @group.teams.map { |team| row_for(team, base[team.id]) }
    by_team = rows.index_by { |r| r.team.id }

    @live.each do |m|
      apply_live(by_team[m.home_team_id], m.home_goals, m.away_goals)
      apply_live(by_team[m.away_team_id], m.away_goals, m.home_goals)
    end

    if @live.any?
      rows.sort_by! { |r| [ -r.points, -r.goal_difference, -r.goals_for, r.team.name ] }
      rows.each_with_index { |r, i| r.rank = i + 1 }
      rows
    else
      rows.sort_by { |r| r.rank || 99 }
    end
  end

  private

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

  def apply_live(row, scored, conceded)
    return if row.nil?
    row.live = true
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
