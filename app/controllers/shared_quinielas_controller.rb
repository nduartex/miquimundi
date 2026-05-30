class SharedQuinielasController < ApplicationController
  # Public, read-only view of a quiniela's predictions. No login required
  # (require_login is opt-in per controller, so it is intentionally absent here).
  def show
    @quiniela = Quiniela.find_by!(share_token: params[:token])
    @owner = @quiniela.user
    @tournament = @quiniela.tournament
    @groups = @tournament.groups.includes(:teams).order(:name)
    @knockouts = @tournament.matches.knockout.ordered
    @players = Player.includes(:team).order("teams.name")
    @teams = Team.joins(:group).where(groups: { tournament_id: @tournament.id }).order(:name)
  end
end
