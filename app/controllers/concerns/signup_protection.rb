# Invisible anti-bot protection for the registration form. No third-party
# services: a honeypot field catches form-filling bots, and a signed timestamp
# rejects instant/scripted and stale submissions. See
# docs/superpowers/specs/2026-05-31-anti-bot-registration-design.md.
module SignupProtection
  extend ActiveSupport::Concern

  # A human needs at least this long to fill the form; faster ⇒ a bot.
  SIGNUP_MIN_SECONDS = 2.5
  # A form older than this is stale (left open too long / replayed).
  SIGNUP_MAX_SECONDS = 2.hours.to_i

  # Per-IP account-creation caps (count successful signups only). Generous, since
  # families/offices share a WiFi/NAT — the honeypot and time-trap do the heavy
  # lifting against bots.
  SIGNUP_BURST_MAX = 3
  SIGNUP_BURST_WINDOW = 30.seconds
  SIGNUP_HOURLY_MAX = 10
  SIGNUP_HOURLY_WINDOW = 1.hour

  private

  # A hidden field humans never see; bots that auto-fill every input trip it.
  def honeypot_tripped?
    params[:nickname].present?
  end

  # Signed token embedded when the form renders, so the elapsed fill time can be
  # verified on submit without trusting the client clock.
  def signup_timestamp
    signup_verifier.generate(Time.current.to_f)
  end

  # Returns :expired (missing/forged/too old), :too_fast (instant submit), or
  # nil when the timing looks human.
  def signup_timestamp_problem
    ts = signup_verifier.verified(params[:signup_ts].to_s)
    return :expired unless ts.is_a?(Numeric)

    elapsed = Time.current.to_f - ts
    return :expired if elapsed > SIGNUP_MAX_SECONDS
    return :too_fast if elapsed < SIGNUP_MIN_SECONDS

    nil
  end

  def signup_verifier
    Rails.application.message_verifier(:signup)
  end

  # True when this IP already hit either account-creation cap.
  def signup_rate_limited?
    read_count(burst_key) >= SIGNUP_BURST_MAX || read_count(hourly_key) >= SIGNUP_HOURLY_MAX
  end

  # Count a successful signup against both windows for this IP.
  def register_signup!
    bump(burst_key, SIGNUP_BURST_WINDOW)
    bump(hourly_key, SIGNUP_HOURLY_WINDOW)
  end

  def burst_key  = "signup:burst:#{request.remote_ip}"
  def hourly_key = "signup:hour:#{request.remote_ip}"

  def read_count(key) = Rails.cache.read(key).to_i

  def bump(key, window)
    Rails.cache.write(key, read_count(key) + 1, expires_in: window)
  end

  # Generic refusal that never reveals which guard tripped.
  def reject_signup(message = "No se pudo completar el registro, recargá la página e intentá de nuevo.")
    @tournament = Tournament.current
    flash.now[:alert] = message
    render :new, status: :unprocessable_entity
  end

  def reject_signup_rate_limited
    @tournament = Tournament.current
    flash.now[:alert] = "Demasiados registros desde tu red, esperá un momento e intentá de nuevo."
    render :new, status: :too_many_requests
  end
end
