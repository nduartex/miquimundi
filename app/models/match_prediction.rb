class MatchPrediction < ApplicationRecord
  belongs_to :quiniela
  belongs_to :match
  belongs_to :penalty_qualifier, class_name: "Team", optional: true

  def predicted_winner_team_id
    return nil if pred_home.blank? || pred_away.blank?
    return match.home_team_id if pred_home > pred_away
    return match.away_team_id if pred_away > pred_home
    nil
  end
end
