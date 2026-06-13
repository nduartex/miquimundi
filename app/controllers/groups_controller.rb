class GroupsController < ApplicationController
  # Live view of a single group, loaded lazily inside the quiniela's modal.
  # Public on purpose: it only shows real tournament data; the prediction
  # comparison appears only for the signed-in owner.
  def live
    @group = Group.includes(group_standings: :team).find(params[:id])
    @standings = @group.group_standings.ranked.includes(:team)
    @matches = Match.where(phase: "group")
                    .joins("INNER JOIN teams home_teams ON home_teams.id = matches.home_team_id")
                    .where(home_teams: { group_id: @group.id })
                    .includes(:home_team, :away_team, goals: :team)
                    .order(:kickoff_at)
    @prediction = current_user&.quiniela_for(@group.tournament)&.group_predictions
                              &.find_by(group_id: @group.id)
    render layout: false
  end
end
