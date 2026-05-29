class SessionsController < ApplicationController
  def new
    redirect_to quiniela_path if signed_in?
  end

  def create
    user = User.find_or_initialize_by(email: params[:email].to_s.downcase.strip)
    if user.persisted? || user.save
      session[:user_id] = user.id
      redirect_to quiniela_path, notice: "¡Bienvenido, #{user.display_name}!"
    else
      flash.now[:alert] = "Correo inválido."
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    reset_session
    redirect_to new_session_path, notice: "Sesión cerrada."
  end
end
