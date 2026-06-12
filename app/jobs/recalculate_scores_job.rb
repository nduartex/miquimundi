class RecalculateScoresJob < ApplicationJob
  queue_as :default

  def perform(tournament_id)
    tournament = Tournament.find(tournament_id)
    tournament.quinielas_relation.find_each do |q|
      # Prime the association: ScoringService reads quiniela.tournament, which
      # would otherwise be one extra SELECT per quiniela.
      q.association(:tournament).target = tournament
      ScoringService.new(q).call
    end
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
