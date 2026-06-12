class QuinielasController < ApplicationController
  before_action :require_login

  def show
    @tournament = Tournament.current
    @quiniela = current_user.quiniela_for(@tournament)
    @quiniela.save! if @quiniela.new_record?
    @groups = @tournament.groups.includes(:teams).order(:name)
    @knockouts = @tournament.matches.knockout.ordered
    @players = Player.includes(:team).order("teams.name")
    @teams = Team.joins(:group).where(groups: { tournament_id: @tournament.id }).order(:name)
    @knockout_open = @tournament.knockout_open?
    # Per-user: the first part stays open during the late window for users who
    # never completed it (they save once, with a scoring penalty).
    @groups_locked = !@quiniela.first_part_editable?
    @late_window = @tournament.locked? && !@groups_locked
  end
end
