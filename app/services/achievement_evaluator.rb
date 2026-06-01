# Evaluates the achievement catalog against a quiniela's current state, persists
# any newly earned ones, and returns them (as catalog entries). Also maintains
# worst_rank, used by the Remontada rule.
class AchievementEvaluator
  Context = Struct.new(:quiniela, :rank_climb, :current_rank, keyword_init: true)

  def initialize(quiniela, current_rank:)
    @quiniela = quiniela
    @current_rank = current_rank
  end

  def call
    worst = [@quiniela.worst_rank || @current_rank, @current_rank].max
    @quiniela.update!(worst_rank: worst) if worst != @quiniela.worst_rank

    context = Context.new(quiniela: @quiniela, rank_climb: worst - @current_rank,
                          current_rank: @current_rank)
    earned = @quiniela.achievements.pluck(:key)

    AchievementCatalog::ALL.each_with_object([]) do |entry, newly|
      has = earned.include?(entry.key)
      met = entry.rule.call(context)

      # Exclusive badges (e.g. The GOAT) move with the ranking: revoke once the
      # holder no longer meets the rule so only the current leader keeps it.
      if entry.exclusive && has && !met
        @quiniela.achievements.where(key: entry.key).destroy_all
        next
      end

      next if has || !met
      @quiniela.achievements.create!(key: entry.key, earned_at: Time.current)
      newly << entry
    end
  end
end
