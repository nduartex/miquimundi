class PredictionsController < ApplicationController
  before_action :require_login

  def create
    @tournament = Tournament.current
    @quiniela = current_user.quiniela_for(@tournament)
    @quiniela.save! if @quiniela.new_record?

    missing = nil
    saved = false
    ActiveRecord::Base.transaction do
      unless @tournament.locked? # group-stage predictions freeze when the World Cup starts
        save_group_predictions
        save_best_thirds
        save_award_prediction
      end
      save_match_predictions # has its own knockout-open + per-match kickoff guards

      # The first part can only be saved when all three phases are complete. The
      # check is skipped once the tournament is locked (first part already frozen;
      # saves then only carry knockout predictions).
      if !@tournament.locked? && !@quiniela.reload.first_part_complete?
        missing = @quiniela.first_part_missing
        raise ActiveRecord::Rollback
      end

      @quiniela.update!(submitted_at: Time.current)
      saved = true
    end

    unless saved
      msg = "Completa las 3 fases antes de guardar: falta #{missing.join(", ")}."
      respond_to do |format|
        format.html { redirect_to quiniela_path, alert: msg }
        format.turbo_stream { flash.now[:alert] = msg }
      end
      return
    end

    ScoringService.new(@quiniela).call

    respond_to do |format|
      format.html { redirect_to quiniela_path, notice: "¡Quiniela guardada!" }
      format.turbo_stream { flash.now[:notice] = "¡Quiniela guardada!" }
    end
  end

  private

  def save_group_predictions
    (params[:group_predictions] || {}).each do |group_id, attrs|
      next if attrs[:first_team_id].blank?
      gp = @quiniela.group_predictions.find_or_initialize_by(group_id: group_id)
      gp.update!(
        first_team_id: attrs[:first_team_id],
        second_team_id: attrs[:second_team_id],
        third_team_id: attrs[:third_team_id].presence,
        fourth_team_id: attrs[:fourth_team_id].presence
      )
    end
  end

  # Exactly the group letters the user nominated as qualifying best thirds.
  # Pre-lock, an absent param means every checkbox was unchecked, so clear the
  # selection (no stale value survives a "deselect all"). The param is only
  # legitimately absent post-lock, where the first part is already frozen.
  def save_best_thirds
    if params.key?(:best_third_groups)
      letters = Array(params[:best_third_groups]).reject(&:blank?).first(8)
      @quiniela.update!(best_third_groups: letters)
    elsif !@tournament.locked?
      @quiniela.update!(best_third_groups: [])
    end
  end

  def save_match_predictions
    return unless @tournament.knockout_open? # locked until the real group stage ends
    (params[:match_predictions] || {}).each do |match_id, attrs|
      match = @tournament.matches.find(match_id)
      next if match.locked?
      next if attrs[:pred_home].blank? || attrs[:pred_away].blank?
      mp = @quiniela.match_predictions.find_or_initialize_by(match_id: match_id)
      mp.update!(
        pred_home: attrs[:pred_home],
        pred_away: attrs[:pred_away],
        penalty_qualifier_id: attrs[:penalty_qualifier_id].presence
      )
    end
  end

  def save_award_prediction
    attrs = params[:award_prediction]
    return if attrs.blank?
    award = @quiniela.award_prediction || @quiniela.build_award_prediction
    award.update!(AwardPrediction::FIELDS.index_with { |f| attrs[f].presence })
  end
end
