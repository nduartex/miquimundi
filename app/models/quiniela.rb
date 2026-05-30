class Quiniela < ApplicationRecord
  belongs_to :user
  belongs_to :tournament
  has_many :group_predictions, dependent: :destroy
  has_many :match_predictions, dependent: :destroy
  has_one :award_prediction, dependent: :destroy

  has_secure_token :share_token

  def submitted?
    submitted_at.present?
  end

  def predicted_final?
    match_predictions
      .joins(:match)
      .where(matches: { phase: "final" })
      .where.not(pred_home: nil)
      .where.not(pred_away: nil)
      .exists?
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
    return false unless group_predictions.size == expected
    group_predictions.all? { |gp| gp.ranked_team_ids.size == 4 }
  end

  def best_thirds_complete?
    Array(best_third_groups).size == 8
  end

  def awards_complete?
    award_prediction&.complete? || false
  end
end
