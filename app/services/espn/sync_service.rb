module Espn
  # Pulls live data from ESPN and upserts it into our tables. Idempotent and
  # additive: it never deletes matches/standings, so a bad ESPN response can't
  # wipe local data. Scoring is only triggered by events that can actually
  # change points (a group completing, the thirds resolving, a knockout FT) —
  # a single group-stage FT awards nobody anything by design.
  class SyncService
    GROUP_STAGE_DATES = "20260611-20260627".freeze
    TOURNAMENT_DATES = "20260611-20260719".freeze

    # ESPN team abbreviation -> our FIFA code, for the few that differ.
    # Unmatched teams are collected in `unmatched` and logged by the rake task.
    CODE_ALIASES = {}.freeze

    attr_reader :unmatched

    def initialize(tournament, client: Client.new)
      @tournament = tournament
      @client = client
      @unmatched = Set.new
    end

    # dates: ESPN range "YYYYMMDD-YYYYMMDD". standings: :auto (only after a
    # match just finished) or :force (always refresh).
    def sync!(dates: default_dates, standings: :auto)
      events = Array(@client.scoreboard(dates: dates)["events"])
      newly_finished = []
      live = []
      score_changed = []

      events.each do |event|
        match, became_finished, changed = sync_event(event)
        next unless match
        newly_finished << match if became_finished
        live << match if match.status == "live"
        score_changed << match if changed
      end

      # Summaries are only worth fetching when the score moved (goals can't
      # change otherwise); the backfill covers matches synced while down.
      (score_changed + newly_finished + finished_missing_goals).uniq.each { |m| sync_goals(m) }
      sync_standings if standings == :force || newly_finished.any?

      results_changed = finalize_groups
      recalc! if results_changed || newly_finished.any?(&:knockout?)

      if @unmatched.any?
        Rails.logger.warn("[espn] equipos sin mapear: #{@unmatched.to_a.join(", ")}")
      end

      { events: events.size, live: live.size, finished: newly_finished.size,
        recalculated: results_changed || newly_finished.any?(&:knockout?) }
    end

    def sync_standings
      Array(@client.standings["children"]).each do |child|
        group = groups_by_name[child["name"].to_s.sub(/\AGroup /, "")]
        next unless group
        Array(child.dig("standings", "entries")).each do |entry|
          team = resolve_team(entry["team"])
          next unless team
          stats = Array(entry["stats"]).index_by { |s| s["name"] }
          GroupStanding.find_or_initialize_by(group: group, team: team).update!(
            played: stat(stats, "gamesPlayed"),
            wins: stat(stats, "wins"),
            draws: stat(stats, "ties"),
            losses: stat(stats, "losses"),
            goals_for: stat(stats, "pointsFor"),
            goals_against: stat(stats, "pointsAgainst"),
            goal_difference: stat(stats, "pointDifferential"),
            points: stat(stats, "points"),
            rank: stat(stats, "rank").nonzero?
          )
        end
      end
    end

    private

    # ---- scoreboard ----------------------------------------------------------

    # Returns [match, became_finished] (match is nil for unmappable events,
    # e.g. knockout games whose teams aren't defined yet).
    def sync_event(event)
      comp = Array(event["competitions"]).first || {}
      competitors = Array(comp["competitors"])
      home_c = competitors.find { |c| c["homeAway"] == "home" }
      away_c = competitors.find { |c| c["homeAway"] == "away" }
      return [ nil, false ] unless home_c && away_c

      home_team = resolve_team(home_c["team"])
      away_team = resolve_team(away_c["team"])
      match = @tournament.matches.find_by(espn_id: event["id"]) ||
              map_match(event, home_team, away_team)
      return [ nil, false ] unless match

      was_finished = match.status == "finished"
      attrs = { espn_id: event["id"] }
      # ESPN omits seconds ("2026-06-11T19:00Z"), which Time.iso8601 rejects.
      attrs[:kickoff_at] = Time.zone.parse(event["date"]) if event["date"].present?
      status = map_status(comp["status"] || event["status"])
      attrs[:status] = status if status

      state = (comp["status"] || event["status"]).to_h.dig("type", "state")
      # Both competitors must resolve before touching scores: with an
      # unresolved side the lookup hash collapses on a nil key and one
      # competitor's score could land on both columns.
      if state != "pre" && home_team && away_team
        by_team = { home_team.id => home_c, away_team.id => away_c }
        our_home = by_team[match.home_team_id]
        our_away = by_team[match.away_team_id]
        if our_home && our_away
          attrs[:home_goals] = our_home["score"].to_i
          attrs[:away_goals] = our_away["score"].to_i
          if status == "finished" && our_home["shootoutScore"].present? && our_away["shootoutScore"].present?
            attrs[:penalty_winner_id] =
              our_home["shootoutScore"].to_i > our_away["shootoutScore"].to_i ? match.home_team_id : match.away_team_id
          end
        end
      end

      match.update!(attrs)
      changed_score = match.saved_changes.key?("home_goals") || match.saved_changes.key?("away_goals")
      [ match, !was_finished && match.status == "finished", changed_score ]
    end

    def map_status(status)
      type = status.to_h["type"] || {}
      case type["state"]
      when "pre" then "scheduled"
      when "in" then "live"
      when "post"
        # post + !completed = abandoned/suspended. Without this a match that
        # was live would stay "live" forever and block its group's result.
        type["completed"] ? "finished" : "scheduled"
      end
    end

    # First time we see an ESPN event: create the group match (the 72 group
    # games don't exist in the DB) or attach the id to an existing knockout
    # match once its teams are known.
    def map_match(event, home_team, away_team)
      return nil unless home_team && away_team

      if home_team.group_id == away_team.group_id
        # create_or_find_by! leans on the unique index (tournament, home, away)
        # so overlapping syncs can't insert the same fixture twice.
        @tournament.matches.create_or_find_by!(
          phase: "group", home_team: home_team, away_team: away_team
        ) { |m| m.status = "scheduled" }
      else
        @tournament.matches.knockout.where(espn_id: nil).find_by(
          "(home_team_id = :h AND away_team_id = :a) OR (home_team_id = :a AND away_team_id = :h)",
          h: home_team.id, a: away_team.id
        )
      end
    end

    # ---- goals ---------------------------------------------------------------

    COMPARABLE_GOAL_FIELDS = %i[team_id player_name minute own_goal penalty sort_order].freeze

    def sync_goals(match)
      return if match.espn_id.blank?
      key_events = Array(@client.summary(match.espn_id)["keyEvents"])
      rows = key_events.select { |e| e["scoringPlay"] && !e["shootout"] }
                       .each_with_index.filter_map { |ev, i| goal_row(match, ev, i) }

      # Skip the rewrite when nothing changed — the common case on live
      # cycles; avoids row churn and keeps goals.updated_at meaningful.
      incoming = rows.map { |r| [ r[:team].id, r[:player_name], r[:minute], r[:own_goal], r[:penalty], r[:sort_order] ] }
      existing = match.goals.in_order.pluck(*COMPARABLE_GOAL_FIELDS)
      return if incoming == existing

      Match.transaction do
        match.goals.destroy_all
        rows.each { |row| match.goals.create!(row) }
      end
    end

    def goal_row(match, ev, index)
      team = team_by_espn_id(ev.dig("team", "id"))
      name = ev.dig("participants", 0, "athlete", "displayName")
      return nil unless team && name.present?
      type_text = ev.dig("type", "text").to_s
      {
        team: team,
        player_name: name,
        player: link_player(match, name),
        minute: ev.dig("clock", "displayValue"),
        own_goal: type_text.match?(/own goal/i),
        penalty: type_text.match?(/penalty/i),
        sort_order: index
      }
    end

    # Best-effort link to our seeded rosters (used later for award cross-refs).
    # Accent/case-insensitive exact match across both teams' squads.
    def link_player(match, name)
      @rosters ||= {}
      roster = (@rosters[match.id] ||= Player.where(team_id: [ match.home_team_id, match.away_team_id ].compact)
                                             .index_by { |p| normalize(p.name) })
      roster[normalize(name)]
    end

    def normalize(name)
      I18n.transliterate(name.to_s).downcase.strip
    end

    # Finished matches whose goal rows don't add up (e.g. synced while the
    # process was down). 0-0 games add up trivially, so no refetch loop, and
    # the recency cutoff stops a permanently unattributable ESPN goal (no
    # athlete/team in the keyEvent) from triggering a refetch every minute
    # for the rest of the tournament.
    def finished_missing_goals
      @tournament.matches.where(status: "finished").where.not(espn_id: nil)
                 .where(kickoff_at: 3.days.ago..)
                 .left_joins(:goals).group(:id)
                 .having("COUNT(goals.id) <> matches.home_goals + matches.away_goals")
    end

    # ---- group results / thirds ----------------------------------------------

    def finalize_groups
      changed = false
      @tournament.groups.includes(:group_result).each do |group|
        next if group.group_result
        matches = group_matches(group)
        next unless matches.size == 6 && matches.all?(&:finished?)
        top2 = group.group_standings.ranked.first(2)
        # played == 3 proves the standings already include the last matchday;
        # without it a lagging/failed standings fetch would lock in qualifiers
        # from stale ranks (GroupResult is permanent once created).
        next unless top2.size == 2 && top2.all? { |s| s.rank.present? && s.played == 3 }
        GroupResult.create!(group: group, first_team_id: top2[0].team_id, second_team_id: top2[1].team_id)
        changed = true
      end
      # Always attempt thirds: cheap guards inside, and it self-heals if a
      # previous run created the last GroupResult but crashed before this step.
      resolve_thirds || changed
    end

    # FIFA ranks best thirds by points, then goal difference, then goals
    # scored. (Deeper tiebreakers — fair play, drawing of lots — are out of our
    # reach; ESPN's per-group rank doesn't order thirds across groups.) The
    # list stays recomputable until the first knockout kicks off, so a late
    # standings correction — or FIFA resolving a tie we can't model — can
    # still fix it; after kickoff it's frozen because points were paid.
    def resolve_thirds
      return false unless @tournament.groups.includes(:group_result).all?(&:group_result)
      result = TournamentResult.find_or_initialize_by(tournament: @tournament)
      return false if result.qualified_third_codes.present? && knockouts_started?

      thirds = GroupStanding.where(group: @tournament.groups, rank: 3).includes(:team)
                            .sort_by { |s| [ -s.points, -s.goal_difference, -s.goals_for ] }
                            .first(8)
      return false unless thirds.size == 8

      codes = thirds.map { |s| s.team.code }
      return false if result.qualified_third_codes == codes

      result.update!(qualified_third_codes: codes)
      true
    end

    def knockouts_started?
      @tournament.matches.knockout.where.not(kickoff_at: nil)
                 .where(kickoff_at: ..Time.current).exists?
    end

    def group_matches(group)
      @tournament.matches.where(phase: "group")
                 .joins("INNER JOIN teams home_teams ON home_teams.id = matches.home_team_id")
                 .where(home_teams: { group_id: group.id })
    end

    def recalc!
      RecalculateScoresJob.perform_later(@tournament.id)
    end

    # ---- team resolution ------------------------------------------------------

    def resolve_team(team_json)
      team_json = team_json.to_h
      espn_id = team_json["id"].to_s
      abbr = team_json["abbreviation"].to_s

      team = team_by_espn_id(espn_id) ||
             teams_by_code[abbr] ||
             teams_by_code[CODE_ALIASES[abbr]]
      if team.nil?
        # Knockout placeholders ("Group A Winner", "RD16 W2") aren't real teams.
        placeholder = team_json["displayName"].to_s.match?(/winner|2nd place|third place|loser|tbd/i)
        @unmatched << "#{abbr} (#{team_json["displayName"]}, espn:#{espn_id})" if abbr.present? && !placeholder
        return nil
      end
      if team.espn_id.blank? && espn_id.present?
        team.update!(espn_id: espn_id)
        @teams_by_espn_id = nil
      end
      team
    end

    def team_by_espn_id(espn_id)
      return nil if espn_id.blank?
      (@teams_by_espn_id ||= tournament_teams.index_by(&:espn_id))[espn_id.to_s]
    end

    def teams_by_code
      @teams_by_code ||= tournament_teams.index_by(&:code)
    end

    def tournament_teams
      @tournament_teams ||= Team.joins(:group).where(groups: { tournament_id: @tournament.id }).to_a
    end

    def groups_by_name
      @groups_by_name ||= @tournament.groups.index_by(&:name)
    end

    def stat(stats, name)
      stats[name]&.dig("value").to_i
    end

    # Yesterday..tomorrow (UTC) covers late kickoffs that cross midnight.
    def default_dates
      today = Time.now.utc.to_date
      "#{(today - 1).strftime("%Y%m%d")}-#{(today + 1).strftime("%Y%m%d")}"
    end
  end
end
