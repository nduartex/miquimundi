class RankingsController < ApplicationController
  def index
    @tournament = Tournament.current
    @quinielas = self.class.ranked(@tournament)
    @leader_points = @quinielas.first&.total_points || 0
  end

  def self.ranked(tournament)
    Quiniela.where(tournament_id: tournament.id)
            .includes(:user)
            .order(total_points: :desc, exact_hits: :desc, match_hits: :desc)
  end
end
