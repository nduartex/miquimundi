class LigasController < ApplicationController
  before_action :require_login
  before_action :set_liga, only: %i[show edit update destroy leave expel]
  before_action :require_membership, only: %i[show leave]
  before_action :require_creator, only: %i[edit update destroy expel]

  def index
    @ligas = current_user.ligas.includes(:creator, :memberships).order(created_at: :desc)
    @liga = Liga.new
  end

  def new
    @liga = Liga.new(max_players: 10)
  end

  def create
    @liga = Liga.new(liga_params)
    @liga.creator = current_user
    @liga.tournament = Tournament.current

    ActiveRecord::Base.transaction do
      @liga.save!
      @liga.memberships.create!(user: current_user)
    end
    redirect_to @liga, notice: "Liga creada. Comparte el código #{@liga.invite_code} con tus amigos."
  rescue ActiveRecord::RecordInvalid
    flash.now[:alert] = @liga.errors.full_messages.first || "No se pudo crear la liga."
    render :new, status: :unprocessable_entity
  end

  def edit
  end

  def update
    if @liga.update(liga_params)
      redirect_to @liga, notice: "Liga actualizada."
    else
      flash.now[:alert] = @liga.errors.full_messages.first || "No se pudo actualizar la liga."
      render :edit, status: :unprocessable_entity
    end
  end

  def show
    @tournament = @liga.tournament
    @quinielas = Quiniela.ranked(@tournament, user_ids: @liga.member_ids)
    @members_without_quiniela = @liga.members.where.not(id: @quinielas.map(&:user_id))
    assign_prize_outcome
  end

  # POST /ligas/join — join by invite code.
  def join
    code = params[:invite_code].to_s.strip.upcase
    liga = Liga.find_by(invite_code: code)
    return redirect_to ligas_path, alert: "Código inválido." if liga.nil?

    # Serialize membership/capacity checks against concurrent joins so two
    # people can't slip past max_players (or the same person double-submit).
    result = liga.with_lock do
      if liga.member?(current_user)
        :already
      elsif liga.full?
        :full
      else
        liga.memberships.create!(user: current_user)
        :joined
      end
    end

    case result
    when :already then redirect_to liga, notice: "Ya estás en esta liga."
    when :full    then redirect_to ligas_path, alert: "La liga está completa."
    else               redirect_to liga, notice: "Te uniste a #{liga.name}."
    end
  end

  def destroy
    if @liga.deletable_by?(current_user)
      @liga.destroy
      redirect_to ligas_path, notice: "Liga eliminada."
    else
      redirect_to @liga, alert: "Solo puedes borrar la liga cuando no quede nadie más."
    end
  end

  # DELETE /ligas/:id/leave — a member leaves; the creator cannot.
  def leave
    if @liga.creator?(current_user)
      redirect_to @liga, alert: "El creador no puede abandonar su liga."
    else
      @liga.memberships.where(user_id: current_user.id).destroy_all
      redirect_to ligas_path, notice: "Saliste de #{@liga.name}."
    end
  end

  # DELETE /ligas/:id/members/:membership_id — creator expels another member.
  def expel
    membership = @liga.memberships.find(params[:membership_id])
    if membership.user_id == current_user.id
      redirect_to @liga, alert: "No puedes expulsarte a ti mismo."
    else
      membership.destroy
      redirect_to @liga, notice: "Jugador expulsado."
    end
  end

  private

  def set_liga
    @liga = Liga.find(params[:id])
  end

  def require_membership
    redirect_to ligas_path, alert: "No perteneces a esta liga." unless @liga.member?(current_user)
  end

  def require_creator
    redirect_to @liga, alert: "Solo el creador puede hacer eso." unless @liga.creator?(current_user)
  end

  def liga_params
    permitted = %i[name max_players]
    # Prize rules can't change once the tournament is over (the game is decided).
    permitted += %i[has_prize prize_pot] if prize_editable?
    params.require(:liga).permit(*permitted)
  end

  # The prize can be set/changed while the tournament hasn't finished. On create
  # there is no @liga yet, so fall back to the current tournament.
  def prize_editable?
    tournament = @liga&.tournament || Tournament.current
    !tournament&.finished?
  end
  helper_method :prize_editable?

  # Once the tournament is finished, the liga leader is the prize winner — unless
  # the very top is an exact tie (same points and tiebreakers), which the app
  # can't resolve, so the participants settle it themselves.
  def assign_prize_outcome
    @prize_winner = nil
    @prize_tie = false
    return unless @liga.has_prize? && @tournament.finished?

    leader = @quinielas.first
    return if leader.nil?

    runner_up = @quinielas.second
    @prize_tie = runner_up.present? && tied_for_first?(leader, runner_up)
    @prize_winner = leader unless @prize_tie
  end

  def tied_for_first?(a, b)
    a.total_points == b.total_points &&
      a.exact_hits == b.exact_hits &&
      a.match_hits == b.match_hits
  end
end
