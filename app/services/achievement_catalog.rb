# Single source of truth for the achievements: their display data and the rule
# that earns each. Rules receive a context exposing `quiniela` and `rank_climb`.
module AchievementCatalog
  Entry = Struct.new(:key, :name, :emoji, :description, :rule, keyword_init: true)

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
  ].freeze

  # Big achievements trigger the louder ("epic") celebration.
  EPIC_KEYS = %w[nostradamus].freeze

  def self.find(key)
    ALL.find { |e| e.key == key }
  end
end
