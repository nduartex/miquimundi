class SessionsController < ApplicationController
  def new
    redirect_to quiniela_path if signed_in?
    @tournament = Tournament.current
  end

  # Registers a new username (rejects duplicates). Re-entry is via the personal
  # access link, not by retyping the username — so nobody can impersonate.
  def create
    user = User.new(username: params[:username], favorite_team_id: params[:favorite_team_id].presence)
    if user.save
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
end
