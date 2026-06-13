class ScorersController < ApplicationController
  Row = Struct.new(:player_name, :team, :goals, :penalties, keyword_init: true)

  # Public tournament scorer table, derived from per-match goal events (own
  # goals credit no one). Few hundred rows at most, so grouping in Ruby is fine.
  def index
    goals = Goal.scored.includes(:team)
    @rows = goals.group_by { |g| [ g.player_name, g.team_id ] }.map do |(name, _), gs|
      Row.new(player_name: name, team: gs.first.team,
              goals: gs.size, penalties: gs.count(&:penalty))
    end.sort_by { |r| [ -r.goals, r.player_name ] }
    @updated_at = goals.map(&:updated_at).max
  end
end
