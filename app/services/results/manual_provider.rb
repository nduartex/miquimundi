module Results
  class ManualProvider < BaseProvider
    def apply!
      apply_group_results
      apply_matches
      apply_awards
    end

    private

    def teams
      @teams ||= @tournament.groups.flat_map(&:teams).index_by(&:code)
    end

    def players
      @players ||= Player.where(team: teams.values).index_by(&:name)
    end

    def apply_group_results
      Array(@data["group_results"]).each do |row|
        group = @tournament.groups.find_by(name: row["group"])
        next unless group
        first = teams[row["first"]]
        second = teams[row["second"]]
        next unless first && second
        result = GroupResult.find_or_initialize_by(group: group)
        result.update!(first_team: first, second_team: second)
      end
    end

    def apply_matches
      Array(@data["matches"]).each do |row|
        match = @tournament.matches.find_by(bracket_slot: row["bracket_slot"])
        next unless match
        match.update!(
          home_team: row["home"] ? teams[row["home"]] : match.home_team,
          away_team: row["away"] ? teams[row["away"]] : match.away_team,
          home_goals: row["home_goals"],
          away_goals: row["away_goals"],
          penalty_winner: row["penalty_winner"] ? teams[row["penalty_winner"]] : nil,
          status: "finished"
        )
      end
    end

    def apply_awards
      awards = @data["awards"]
      return unless awards
      result = TournamentResult.find_or_initialize_by(tournament: @tournament)
      result.update!(
        top_scorer_player: awards["top_scorer"] ? players[awards["top_scorer"]] : result.top_scorer_player,
        top_assists_player: awards["top_assists"] ? players[awards["top_assists"]] : result.top_assists_player
      )
    end
  end
end
