class SeedLoader
  def self.call
    new.call
  end

  # Upsert only the rosters (teams + players + positions) from the YAML.
  # Does NOT touch tournament settings (locked_at/name) or the bracket, so it
  # is safe to run in production whenever a squad changes. Returns counts.
  # Use the `players:sync` rake task as the entry point.
  def self.sync_players(data = nil)
    new.sync_players(data)
  end

  def call
    data = load_data
    tournament = Tournament.find_or_create_by!(year: data["tournament"]["year"]) do |t|
      t.name = data["tournament"]["name"]
    end
    tournament.update!(
      name: data["tournament"]["name"],
      locked_at: data["tournament"]["starts_at"],
      late_deadline_at: data["tournament"]["late_deadline_at"]
    )

    upsert_rosters(tournament, data)

    slots = data["knockout_slots"]
    slots.each do |slot|
      match = Match.find_or_initialize_by(tournament: tournament, bracket_slot: slot["bracket_slot"])
      match.assign_attributes(
        phase: slot["phase"],
        match_number: slot["match_number"],
        home_label: slot["home_label"],
        away_label: slot["away_label"],
        advances_to: slot["advances_to"].presence
      )
      match.status ||= "scheduled"
      match.save!
    end

    # Remove knockout matches no longer part of the bracket definition
    # (keeps re-seeding idempotent after a structure change).
    tournament.matches
              .where.not(phase: "group")
              .where.not(bracket_slot: slots.map { |s| s["bracket_slot"] })
              .destroy_all

    tournament
  end

  # Roster-only upsert. Requires the tournament to already exist (created by a
  # full `call`). Returns { teams:, created:, updated: } counts.
  def sync_players(data = nil)
    data = data || load_data
    tournament = Tournament.find_by(year: data["tournament"]["year"])
    raise "Tournament #{data["tournament"]["year"]} not found — run the full seed first" unless tournament

    upsert_rosters(tournament, data)
  end

  private

  def load_data
    YAML.safe_load_file(Rails.root.join("db/seeds/world_cup_2026.yml"))
  end

  def upsert_rosters(tournament, data)
    counts = { teams: 0, created: 0, updated: 0 }

    data["groups"].each do |group_name, teams|
      group = Group.find_or_create_by!(tournament: tournament, name: group_name)
      teams.each do |team_data|
        team = Team.find_or_create_by!(group: group, code: team_data["code"]) do |t|
          t.name = team_data["name"]
          t.flag_emoji = team_data["flag"]
        end
        counts[:teams] += 1

        Array(team_data["players"]).each do |player_data|
          # Players may be a bare name (legacy) or a { name:, position: } hash.
          name     = player_data.is_a?(Hash) ? player_data["name"] : player_data
          position = player_data.is_a?(Hash) ? player_data["position"] : nil
          player = Player.find_or_create_by!(team: team, name: name) { counts[:created] += 1 }
          if position.present? && player.position != position
            player.update!(position: position)
            counts[:updated] += 1
          end
        end
      end
    end

    counts
  end
end
