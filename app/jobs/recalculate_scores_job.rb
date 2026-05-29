class RecalculateScoresJob < ApplicationJob
  queue_as :default

  def perform(tournament_id)
    tournament = Tournament.find(tournament_id)
    Quiniela.where(tournament_id: tournament.id).find_each do |quiniela|
      ScoringService.new(quiniela).call
    end
    Turbo::StreamsChannel.broadcast_replace_to(
      "ranking_#{tournament.id}",
      target: "ranking",
      partial: "rankings/table",
      locals: { quinielas: RankingsController.ranked(tournament) }
    )
  end
end
