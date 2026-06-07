# Append-only feed entry: everything that happens inside a liga (joins, leaves,
# expulsions, admin config changes) so every member can see it. The actor's
# display name is snapshotted into metadata at record time, so rendering never
# joins users and the log stays accurate even if names change later.
class LigaActivity < ApplicationRecord
  # Frozen list so a typo in a controller call fails loudly at record time
  # instead of rendering a blank line in the feed.
  ACTIONS = %w[
    created joined left expelled
    renamed cupo_changed
    prize_enabled prize_disabled prize_pot_changed
  ].freeze

  FEED_LIMIT = 30

  belongs_to :liga
  belongs_to :user, optional: true

  validates :action, presence: true, inclusion: { in: ACTIONS }

  # id desempata entre actividades creadas en el mismo update (mismo created_at).
  scope :recent, -> { order(created_at: :desc, id: :desc) }
end
