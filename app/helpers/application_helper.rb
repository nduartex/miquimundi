module ApplicationHelper
  # "75%" — keeps every mention of the late penalty in sync with the real
  # multiplier applied by ScoringService.
  def late_points_percent
    "#{(ScoringService::LATE_MULTIPLIER * 100).round}%"
  end

  # Public Discord invite — single source of truth for every CTA in the app.
  def discord_invite_url
    "https://discord.gg/ryrd3VTuwp"
  end
end
