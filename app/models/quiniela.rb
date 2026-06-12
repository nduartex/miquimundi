class Quiniela < ApplicationRecord
  belongs_to :user
  belongs_to :tournament
  has_many :group_predictions, dependent: :destroy
  has_many :match_predictions, dependent: :destroy
  has_one :award_prediction, dependent: :destroy
  has_many :achievements, dependent: :destroy

  has_secure_token :share_token

  # Ranking order used by both the global ranking and the private ligas. Pass
  # `user_ids:` to restrict the ranking to a liga's members; omit it for the
  # global ranking.
  scope :ranked, ->(tournament, user_ids: nil) {
    rel = where(tournament_id: tournament.id)
            .includes(:achievements, :tournament, user: :favorite_team)
            .order(total_points: :desc, exact_hits: :desc, match_hits: :desc)
    user_ids ? rel.where(user_id: user_ids) : rel
  }

  def submitted?
    submitted_at.present?
  end

  # Completed the first part after kickoff (late window). Phase-1 points get
  # ScoringService::LATE_MULTIPLIER applied, and the ranking shows a badge.
  # submitted_at can't be the marker: it moves on every save (knockouts too).
  def late?
    first_part_completed_at.present? &&
      tournament.locked_at.present? &&
      first_part_completed_at > tournament.locked_at
  end

  # The first part (Grupos + Terceros + Premios) is editable before kickoff,
  # or during the late window for users who never completed it. A late save
  # sets first_part_completed_at, so it self-locks after one submission.
  def first_part_editable?
    !tournament.locked? || (tournament.late_window_open? && first_part_completed_at.nil?)
  end

  def predicted_final?
    match_predictions
      .joins(:match)
      .where(matches: { phase: "final" })
      .where.not(pred_home: nil)
      .where.not(pred_away: nil)
      .exists?
  end

  # Approximate live rank within the tournament (ties ignored — fine for the
  # "+10 places" achievement trigger).
  def current_rank
    tournament.quinielas_relation.where("total_points > ?", total_points).count + 1
  end

  def final_match
    tournament.matches.find_by(phase: "final")
  end

  def predicted_champion
    m = final_match
    return nil unless m
    mp = match_predictions.find_by(match_id: m.id)
    return nil unless mp
    Team.find_by(id: mp.predicted_winner_team_id || mp.penalty_qualifier_id)
  end

  def real_champion
    m = final_match
    return nil unless m&.finished?
    Team.find_by(id: m.actual_winner_team_id || m.penalty_winner_id)
  end

  def champion_correct?
    predicted = predicted_champion
    real = real_champion
    predicted.present? && real.present? && predicted.id == real.id
  end

  # The "first part" (Grupos + Terceros + Premios) is complete only when all
  # three phases are fully marked. Knockouts open later and are not part of this.
  def first_part_complete?
    groups_complete? && best_thirds_complete? && awards_complete?
  end

  # Spanish labels describing what is still missing, for the save alert.
  def first_part_missing
    missing = []
    missing << "ordenar los grupos" unless groups_complete?
    unless best_thirds_complete?
      missing << "los 8 mejores terceros (#{Array(best_third_groups).size}/8)"
    end
    missing << "los 5 premios" unless awards_complete?
    missing
  end

  private

  def groups_complete?
    expected = tournament.groups.count
    return false if expected.zero?
    preds = group_predictions.to_a
    return false unless preds.size == expected
    preds.all? { |gp| gp.ranked_team_ids.size == 4 }
  end

  def best_thirds_complete?
    Array(best_third_groups).size == 8
  end

  def awards_complete?
    award_prediction&.complete? || false
  end
end
