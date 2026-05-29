class GroupPrediction < ApplicationRecord
  belongs_to :quiniela
  belongs_to :group
  belongs_to :first_team, class_name: "Team", optional: true
  belongs_to :second_team, class_name: "Team", optional: true
  belongs_to :third_team, class_name: "Team", optional: true
  belongs_to :fourth_team, class_name: "Team", optional: true

  validate :teams_must_differ

  # Scoring only uses the two qualifiers; 3rd/4th feed the predicted bracket.
  def predicted_team_ids
    [first_team_id, second_team_id].compact
  end

  # Full predicted standing 1st..4th (ids), in order.
  def ranked_team_ids
    [first_team_id, second_team_id, third_team_id, fourth_team_id].compact
  end

  private

  def teams_must_differ
    return if first_team_id.blank? || second_team_id.blank?
    errors.add(:second_team, "must differ from first") if first_team_id == second_team_id
  end
end
