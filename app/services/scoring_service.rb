class ScoringService
  POINTS_PER_QUALIFIED = 3
  EXACT_ORDER_BONUS = 2
  EXACT_SCORE = 5
  CORRECT_WINNER = 2
  CORRECT_PENALTY = 3
  AWARD_POINTS = 10

  def initialize(quiniela)
    @quiniela = quiniela
  end

  def call
    total = 0
    exact_hits = 0
    match_hits = 0

    total += score_groups

    @quiniela.update!(total_points: total, exact_hits: exact_hits, match_hits: match_hits)
  end

  private

  def score_groups
    sum = 0
    @quiniela.group_predictions.includes(:group).each do |gp|
      result = GroupResult.find_by(group_id: gp.group_id)
      points = group_points(gp, result)
      gp.update!(points_earned: points)
      sum += points
    end
    sum
  end

  def group_points(prediction, result)
    return 0 if result.nil?
    actual = result.qualified_team_ids
    predicted = prediction.predicted_team_ids
    correct = (predicted & actual).size
    points = correct * POINTS_PER_QUALIFIED
    if prediction.first_team_id == result.first_team_id &&
       prediction.second_team_id == result.second_team_id
      points += EXACT_ORDER_BONUS
    end
    points
  end
end
