class QuinielasController < ApplicationController
  before_action :require_login

  def show
    @tournament = Tournament.current
    @quiniela = current_user.quiniela_for(@tournament)
    @quiniela.save! if @quiniela.new_record?
    @groups = @tournament.groups.includes(:teams).order(:name)
    @knockouts = @tournament.matches.knockout.ordered
    @players = Player.includes(:team).order("teams.name")
  end
end
