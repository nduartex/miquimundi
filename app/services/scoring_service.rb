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
    @exact_hits = 0
    @match_hits = 0

    total += score_groups
    total += score_matches
    total += score_awards

    @quiniela.update!(total_points: total, exact_hits: @exact_hits, match_hits: @match_hits)
  end

  private

  def score_awards
    award = @quiniela.award_prediction
    result = @quiniela.tournament.tournament_result
    return 0 if award.nil? || result.nil?

    sum = 0
    if award.top_scorer_player_id.present? &&
       award.top_scorer_player_id == result.top_scorer_player_id
      sum += AWARD_POINTS
    end
    if award.top_assists_player_id.present? &&
       award.top_assists_player_id == result.top_assists_player_id
      sum += AWARD_POINTS
    end
    award.update!(points_earned: sum)
    sum
  end

  def score_matches
    sum = 0
    @quiniela.match_predictions.includes(:match).each do |mp|
      match = mp.match
      next unless match.finished?
      raw = match_points(mp, match)
      points = (raw * match.multiplier).floor
      mp.update!(points_earned: points)
      sum += points
    end
    sum
  end

  def match_points(prediction, match)
    points = 0
    exact = prediction.pred_home == match.home_goals && prediction.pred_away == match.away_goals
    if exact
      points += EXACT_SCORE
      @exact_hits += 1
      @match_hits += 1
    elsif prediction.predicted_winner_team_id.present? &&
          prediction.predicted_winner_team_id == match.actual_winner_team_id
      points += CORRECT_WINNER
      @match_hits += 1
    end
    if match.penalty_winner_id.present? &&
       prediction.penalty_qualifier_id == match.penalty_winner_id
      points += CORRECT_PENALTY
    end
    points
  end

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
