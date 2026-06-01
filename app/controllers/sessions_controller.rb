class SessionsController < ApplicationController
  include SignupProtection

  # Every rendered form (initial or re-rendered after an error/limit) needs a
  # fresh signed timestamp, so a normal error doesn't leave the user with an
  # empty/stale token that the time-trap would then reject. Declared before the
  # rate-limit guard so even a 429 page carries a usable timestamp.
  before_action :assign_signup_timestamp, only: %i[new create]

  # Raw per-IP guard against hammering the endpoint (counts every request).
  rate_limit to: 20, within: 1.minute, only: :create, with: -> { reject_signup_rate_limited }

  def new
    redirect_to quiniela_path if signed_in?
    @tournament = Tournament.current
  end

  # Registers a new username (rejects duplicates). Re-entry is via the personal
  # access link, not by retyping the username — so nobody can impersonate.
  def create
    return reject_signup if honeypot_tripped?

    case signup_timestamp_problem
    when :expired  then return reject_signup("El formulario expiró, recargá la página e intentá de nuevo.")
    when :too_fast then return reject_signup
    end

    return reject_signup_rate_limited if signup_rate_limited?

    user = User.new(username: params[:username], favorite_team_id: params[:favorite_team_id].presence)
    if user.save
      register_signup!
      session[:user_id] = user.id
      redirect_to quiniela_path(welcome: 1), notice: "¡Listo, #{user.display_name}! Guarda tu enlace de acceso."
    else
      @tournament = Tournament.current
      flash.now[:alert] = user.errors[:username].first || "No se pudo crear el usuario."
      render :new, status: :unprocessable_entity
    end
  end

  # Log back in via the personal access link.
  def restore
    user = User.find_by(access_token: params[:token])
    if user
      session[:user_id] = user.id
      redirect_to quiniela_path, notice: "¡Bienvenido de vuelta, #{user.display_name}!"
    else
      redirect_to new_session_path, alert: "Enlace de acceso inválido."
    end
  end

  def destroy
    reset_session
    redirect_to new_session_path, notice: "Sesión cerrada."
  end

  private

  def assign_signup_timestamp
    @signup_ts = signup_timestamp
  end
end
