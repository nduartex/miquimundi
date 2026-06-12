class PredictionsController < ApplicationController
  before_action :require_login

  def create
    @tournament = Tournament.current
    @quiniela = current_user.quiniela_for(@tournament)
    @quiniela.save! if @quiniela.new_record?

    # Editable pre-kickoff, or during the late window for users who never
    # completed the first part (their save self-locks via first_part_completed_at).
    # The lock state is read once and reused for the `late` stamp below, so a
    # save authorized pre-kickoff can never be flagged late even if kickoff
    # happens mid-request.
    locked = @tournament.locked?
    @first_part_editable = @quiniela.first_part_editable?(locked: locked)

    # A form submitted after the window closed (or after a late user's single
    # save) must fail loudly: silently dropping the picks while flashing
    # "guardada" would leave an empty quiniela the user believes is in.
    if !@first_part_editable && first_part_params?
      redirect_to quiniela_path,
                  alert: "Tu quiniela de grupos ya está cerrada: este guardado no se aplicó."
      return
    end

    missing = nil
    saved = false
    just_completed = false
    ActiveRecord::Base.transaction do
      if @first_part_editable
        save_group_predictions
        save_best_thirds
        save_award_prediction
      end
      save_match_predictions # has its own knockout-open + per-match kickoff guards

      # The first part can only be saved when all three phases are complete. The
      # check is skipped once the first part is frozen for this user (saves then
      # only carry knockout predictions).
      if @first_part_editable && !@quiniela.reload.first_part_complete?
        missing = @quiniela.first_part_missing
        raise ActiveRecord::Rollback
      end

      # Mark the milestone the first time the first part is completed, so we only
      # celebrate it once.
      if @first_part_editable && @quiniela.first_part_completed_at.nil?
        @quiniela.first_part_completed_at = Time.current
        @quiniela.late = locked # completed during the late window
        just_completed = true
      end

      @quiniela.update!(submitted_at: Time.current)
      saved = true
    end

    unless saved
      # Redirect (not a turbo_stream): Turbo follows the 302 and renders the flash
      # on the reloaded page — no per-action turbo_stream template needed.
      redirect_to quiniela_path, alert: "Completa las 3 fases antes de guardar: falta #{missing.join(", ")}."
      return
    end

    ScoringService.new(@quiniela).call
    earned = AchievementEvaluator.new(@quiniela, current_rank: @quiniela.current_rank).call

    # First completion shows the milestone modal; newly earned achievements show
    # their banner. Either is its own feedback, so skip the plain toast.
    params_out = {}
    params_out[:fase1] = 1 if just_completed
    params_out[:logros] = earned.map(&:key).join(",") if earned.any?

    if params_out.any?
      redirect_to quiniela_path(params_out)
    else
      redirect_to quiniela_path, notice: "¡Quiniela guardada!"
    end
  end

  private

  # Did this request try to modify the first part (Grupos/Terceros/Premios)?
  def first_part_params?
    params[:group_predictions].present? ||
      params[:best_third_groups].present? ||
      params[:award_prediction].present?
  end

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
  # An absent param means every checkbox was unchecked, so clear the selection
  # (no stale value survives a "deselect all"). Only called while editable.
  def save_best_thirds
    if params.key?(:best_third_groups)
      letters = Array(params[:best_third_groups]).reject(&:blank?).first(8)
      @quiniela.update!(best_third_groups: letters)
    else
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
