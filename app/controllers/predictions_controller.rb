class PredictionsController < ApplicationController
  before_action :require_login

  def create
    @tournament = Tournament.current
    @quiniela = current_user.quiniela_for(@tournament)
    @quiniela.save! if @quiniela.new_record?

    ActiveRecord::Base.transaction do
      save_group_predictions
      save_match_predictions
      save_award_prediction
      @quiniela.update!(submitted_at: Time.current)
    end

    ScoringService.new(@quiniela).call
    QuinielaMailer.confirmation(@quiniela).deliver_later

    respond_to do |format|
      format.html { redirect_to quiniela_path, notice: "¡Quiniela guardada! Revisa tu correo." }
      format.turbo_stream { flash.now[:notice] = "¡Quiniela guardada!" }
    end
  end

  private

  def save_group_predictions
    (params[:group_predictions] || {}).each do |group_id, attrs|
      next if attrs[:first_team_id].blank?
      gp = @quiniela.group_predictions.find_or_initialize_by(group_id: group_id)
      gp.update!(first_team_id: attrs[:first_team_id], second_team_id: attrs[:second_team_id])
    end
  end

  def save_match_predictions
    (params[:match_predictions] || {}).each do |match_id, attrs|
      match = Match.find(match_id)
      next if match.locked?
      next if attrs[:pred_home].blank? || attrs[:pred_away].blank?
      mp = @quiniela.match_predictions.find_or_initialize_by(match_id: match_id)
      mp.update!(pred_home: attrs[:pred_home], pred_away: attrs[:pred_away],
                 penalty_qualifier_id: attrs[:penalty_qualifier_id].presence)
    end
  end

  def save_award_prediction
    attrs = params[:award_prediction]
    return if attrs.blank?
    return unless @quiniela.predicted_final?
    award = @quiniela.award_prediction || @quiniela.build_award_prediction
    award.update!(top_scorer_player_id: attrs[:top_scorer_player_id].presence,
                  top_assists_player_id: attrs[:top_assists_player_id].presence)
  end
end
