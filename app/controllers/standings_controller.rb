class StandingsController < ApplicationController
  # Public group-stage tables, fed by the ESPN sync. Off the pitch the rows come
  # straight from GroupStanding (ESPN's official rank). While a group has a match
  # in progress the table is projected live — see GroupStandingsProjection.
  def index
    tournament = Tournament.current
    groups = tournament ? tournament.groups.order(:name).includes(group_standings: :team, teams: []).to_a : []
    live = live_matches(tournament)

    @rows_by_group = groups.index_with do |group|
      GroupStandingsProjection.call(group, live_matches: live.fetch(group.id, []))
    end
    @groups = groups
    @any_live = live.any?
    @updated_at = GroupStanding.maximum(:updated_at)
  end

  private

  def live_matches(tournament)
    return {} unless tournament
    tournament.matches.where(status: "live").includes(:home_team)
              .group_by { |m| m.home_team&.group_id }
  end
end
