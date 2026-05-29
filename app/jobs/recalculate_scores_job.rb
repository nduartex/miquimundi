class RecalculateScoresJob < ApplicationJob
  queue_as :default

  def perform(tournament_id)
    tournament = Tournament.find(tournament_id)
    Quiniela.where(tournament_id: tournament.id).find_each do |quiniela|
      ScoringService.new(quiniela).call
    end
  end
end
