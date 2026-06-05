class PinSessionsController < ApplicationController
  # Per-IP guard against PIN guessing. Generous enough for fat-fingered humans,
  # tight enough to make brute force impractical from a single network. (A
  # per-user lockout is the natural next step if abuse ever shows up.)
  rate_limit to: 10, within: 1.minute, only: :create, with: -> { reject_login_rate_limited }

  def new
    redirect_to quiniela_path if signed_in?
  end

  # Log in with username + 8-digit PIN. Both bad username and bad PIN return the
  # same generic error, so the form never reveals which usernames exist.
  def create
    user = User.find_by("LOWER(username) = ?", params[:username].to_s.strip.downcase)

    if user&.has_pin? && user.authenticate_pin(params[:pin].to_s)
      reset_session
      session[:user_id] = user.id
      redirect_to quiniela_path, notice: "¡Bienvenido de vuelta, #{user.display_name}!"
    else
      flash.now[:alert] = "Usuario o PIN incorrecto."
      render :new, status: :unprocessable_entity
    end
  end

  private

  def reject_login_rate_limited
    flash.now[:alert] = "Demasiados intentos, esperá un momento e intentá de nuevo."
    render :new, status: :too_many_requests
  end
end
