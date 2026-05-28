class Quiniela < ApplicationRecord
  belongs_to :user
  belongs_to :tournament
  has_many :group_predictions, dependent: :destroy
  has_many :match_predictions, dependent: :destroy
  has_one :award_prediction, dependent: :destroy

  def submitted?
    submitted_at.present?
  end

  def predicted_final?
    match_predictions
      .joins(:match)
      .where(matches: { phase: "final" })
      .where.not(pred_home: nil, pred_away: nil)
      .exists?
  end
end
