class StandingsController < ApplicationController
  # Public group-stage tables, fed by the ESPN sync. Off the pitch the rows come
  # straight from GroupStanding (ESPN's official rank). While a group has a match
  # in progress the table is projected live — see GroupStandingsProjection.
  def index
    tournament = Tournament.current
    groups = tournament ? tournament.groups.order(:name).includes(group_standings: :team, teams: []).to_a : []
    overlay = overlay_matches(tournament)

    @rows_by_group = groups.index_with do |group|
      GroupStandingsProjection.call(group, live_matches: overlay.fetch(group.id, []))
    end
    @groups = groups
    # Banner + auto-refresh only when a row is actually projected live — not at
    # the kickoff instant when status is "live" but the score hasn't synced yet,
    # which would otherwise show a live banner over an unchanged table.
    @any_live = @rows_by_group.values.any? { |rows| rows.any?(&:live?) }
    @updated_at = GroupStanding.maximum(:updated_at)
  end

  private

  # Live matches, plus finished ones so the projection can bridge the window
  # where ESPN's /standings still lags a just-ended match. Finished matches the
  # official table already counts are dropped inside the projection (no double
  # count), so steady state is unchanged.
  def overlay_matches(tournament)
    return {} unless tournament
    tournament.matches.where(phase: "group", status: %w[live finished])
              .includes(:home_team, :goals)
              .group_by { |m| m.home_team&.group_id }
  end
end
