class StandingsController < ApplicationController
  # Public group-stage tables, fed by the ESPN sync (GroupStanding rows carry
  # ESPN's official rank, so tiebreakers are already applied).
  def index
    tournament = Tournament.current
    @groups = tournament ? tournament.groups.order(:name).includes(group_standings: :team, teams: []) : []
    @updated_at = GroupStanding.maximum(:updated_at)
  end
end
