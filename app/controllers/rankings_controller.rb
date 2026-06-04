class RankingsController < ApplicationController
  def index
    @tournament = Tournament.current
    @quinielas = self.class.ranked(@tournament)
    @leader_points = @quinielas.first&.total_points || 0
  end

  def self.ranked(tournament)
    Quiniela.ranked(tournament)
  end
end
