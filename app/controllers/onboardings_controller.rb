class OnboardingsController < ApplicationController
  before_action :require_login

  # Marks the signed-in user as having seen the onboarding tour, so it won't
  # auto-start again on their next visit (account-based, not browser-based).
  def update
    current_user.update(onboarded_at: Time.current)
    head :no_content
  end
end
