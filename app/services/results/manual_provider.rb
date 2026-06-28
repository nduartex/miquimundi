module Results
  class ManualProvider < BaseProvider
    def apply!
      apply_group_results
      apply_matches
      apply_awards
      apply_qualified_thirds
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

    # A row can carry a confirmed-but-unplayed matchup (teams only, no score):
    # that just seeds the bracket slot and leaves the match scheduled, so the
    # bracket/calendar show the real teams while ESPN keeps syncing the kickoff
    # and live result. A row with a score marks the match finished as before.
    def apply_matches
      Array(@data["matches"]).each do |row|
        match = @tournament.matches.find_by(bracket_slot: row["bracket_slot"])
        next unless match
        finished = row["home_goals"].present? && row["away_goals"].present?
        match.update!(
          home_team: row["home"] ? teams[row["home"]] : match.home_team,
          away_team: row["away"] ? teams[row["away"]] : match.away_team,
          home_goals: row["home_goals"],
          away_goals: row["away_goals"],
          penalty_winner: row["penalty_winner"] ? teams[row["penalty_winner"]] : match.penalty_winner,
          status: finished ? "finished" : match.status
        )
      end
    end

    def apply_awards
      awards = @data["awards"]
      return unless awards
      result = TournamentResult.find_or_initialize_by(tournament: @tournament)
      result.update!(
        balon_oro_player:  awards["balon_oro"]  ? players[awards["balon_oro"]]  : result.balon_oro_player,
        bota_oro_player:   awards["bota_oro"]   ? players[awards["bota_oro"]]   : result.bota_oro_player,
        guante_oro_player: awards["guante_oro"] ? players[awards["guante_oro"]] : result.guante_oro_player,
        young_player:      awards["young"]      ? players[awards["young"]]      : result.young_player,
        fair_play_team:    awards["fair_play"]  ? teams[awards["fair_play"]]    : result.fair_play_team
      )
    end

    # Real team codes that qualified as best thirds, e.g. qualified_thirds: [MEX, BRA, ...]
    def apply_qualified_thirds
      codes = @data["qualified_thirds"]
      return if codes.nil?
      result = TournamentResult.find_or_initialize_by(tournament: @tournament)
      result.update!(qualified_third_codes: Array(codes))
    end
  end
end
