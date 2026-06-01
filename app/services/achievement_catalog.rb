# Single source of truth for the achievements: their display data and the rule
# that earns each. Rules receive a context exposing `quiniela`, `rank_climb` and
# `current_rank`. `exclusive` badges are held by a single quiniela at a time and
# are revoked once the rule stops being true (e.g. when overtaken in the ranking).
module AchievementCatalog
  Entry = Struct.new(:key, :name, :emoji, :description, :note, :rule, :exclusive, keyword_init: true)

  ALL = [
    Entry.new(key: "profeta", name: "Profeta", emoji: "🔮",
              description: "Acumula 5 marcadores exactos.",
              rule: ->(c) { c.quiniela.exact_hits >= 5 }),
    Entry.new(key: "nostradamus", name: "Nostradamus", emoji: "🏆",
              description: "Acertaste al campeón del Mundial.",
              rule: ->(c) { c.quiniela.champion_correct? }),
    Entry.new(key: "remontada", name: "Remontada", emoji: "🚀",
              description: "Subiste 10+ puestos en el ranking.",
              rule: ->(c) { c.rank_climb >= 10 }),
    Entry.new(key: "goat", name: "The GOAT", emoji: "🐐", exclusive: true,
              description: "Lidera el ranking con el mayor puntaje.",
              note: "Solo lo tiene una persona a la vez y cambia de dueño según se mueva el ranking.",
              rule: ->(c) { c.current_rank == 1 && c.quiniela.total_points.positive? }),
  ].freeze

  # Big achievements trigger the louder ("epic") celebration.
  EPIC_KEYS = %w[nostradamus goat].freeze

  def self.find(key)
    ALL.find { |e| e.key == key }
  end
end
