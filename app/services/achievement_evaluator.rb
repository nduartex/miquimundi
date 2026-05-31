# Evaluates the achievement catalog against a quiniela's current state, persists
# any newly earned ones, and returns them (as catalog entries). Also maintains
# worst_rank, used by the Remontada rule.
class AchievementEvaluator
  Context = Struct.new(:quiniela, :rank_climb, keyword_init: true)

  def initialize(quiniela, current_rank:)
    @quiniela = quiniela
    @current_rank = current_rank
  end

  def call
    worst = [@quiniela.worst_rank || @current_rank, @current_rank].max
    @quiniela.update!(worst_rank: worst) if worst != @quiniela.worst_rank

    context = Context.new(quiniela: @quiniela, rank_climb: worst - @current_rank)
    earned = @quiniela.achievements.pluck(:key)

    AchievementCatalog::ALL.each_with_object([]) do |entry, newly|
      next if earned.include?(entry.key)
      next unless entry.rule.call(context)
      @quiniela.achievements.create!(key: entry.key, earned_at: Time.current)
      newly << entry
    end
  end
end
