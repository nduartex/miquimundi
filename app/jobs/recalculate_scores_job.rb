class RecalculateScoresJob < ApplicationJob
  queue_as :default

  def perform(tournament_id)
    tournament = Tournament.find(tournament_id)
    tournament.quinielas_relation.find_each { |q| ScoringService.new(q).call }
    RankingsController.ranked(tournament).each_with_index do |quiniela, i|
      AchievementEvaluator.new(quiniela, current_rank: i + 1).call
    end
    Turbo::StreamsChannel.broadcast_replace_to(
      "ranking_#{tournament.id}",
      target: "ranking",
      partial: "rankings/table",
      locals: { quinielas: RankingsController.ranked(tournament) }
    )
  end
end
