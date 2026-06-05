class PinsController < ApplicationController
  before_action :require_login

  # Set the very first PIN (no current PIN to confirm). If they already have one,
  # send them through the change flow instead.
  def create
    return redirect_to(profile_path) if current_user.has_pin?

    if save_pin
      redirect_to profile_path, notice: "¡PIN creado! Ya puedes entrar con tu usuario y PIN."
    else
      flash.now[:alert] = pin_error(current_user)
      render_profile_with_errors
    end
  end

  # Change an existing PIN. Requires the current PIN, so a forgotten-open session
  # on a shared device can't silently reset it.
  def update
    unless current_user.has_pin? && current_user.authenticate_pin(params[:current_pin].to_s)
      flash.now[:alert] = "Tu PIN actual no es correcto."
      return render_profile_with_errors
    end

    if save_pin
      redirect_to profile_path, notice: "PIN actualizado."
    else
      flash.now[:alert] = pin_error(current_user)
      render_profile_with_errors
    end
  end

  private

  # Assigns and persists the new PIN. has_secure_password silently ignores a
  # blank assignment (it neither sets a digest nor fails validation), so a blank
  # PIN would otherwise "succeed" without storing anything — guard it explicitly.
  def save_pin
    attrs = pin_params
    # Guard on the *permitted scalar*, not raw params: a crafted `pin[]=...`
    # (array) survives `params[:pin].blank?` but is dropped by `permit`, which
    # would otherwise "save" with no PIN set and report a false success.
    if attrs[:pin].blank?
      current_user.errors.add(:pin, "debe ser de 8 dígitos numéricos")
      return false
    end

    current_user.assign_attributes(attrs)
    current_user.save
  end

  def pin_params
    params.permit(:pin, :pin_confirmation)
  end

  def pin_error(user)
    user.errors[:pin].first || user.errors[:pin_confirmation].first || "No se pudo guardar el PIN."
  end

  def render_profile_with_errors
    # has_secure_password sets pin_digest in memory the moment `pin` is assigned,
    # even when validation later fails. Roll it back so the page reflects the
    # persisted state (and shows the right create-vs-change form), keeping errors.
    current_user.restore_attributes([ :pin_digest ])
    @user = current_user
    render "profiles/show", status: :unprocessable_entity
  end
end
