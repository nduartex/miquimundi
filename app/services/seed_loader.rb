class SeedLoader
  def self.call
    new.call
  end

  def call
    data = YAML.safe_load_file(Rails.root.join("db/seeds/world_cup_2026.yml"))
    tournament = Tournament.find_or_create_by!(year: data["tournament"]["year"]) do |t|
      t.name = data["tournament"]["name"]
    end

    data["groups"].each do |group_name, teams|
      group = Group.find_or_create_by!(tournament: tournament, name: group_name)
      teams.each do |team_data|
        team = Team.find_or_create_by!(group: group, code: team_data["code"]) do |t|
          t.name = team_data["name"]
          t.flag_emoji = team_data["flag"]
        end
        Array(team_data["players"]).each do |player_name|
          Player.find_or_create_by!(team: team, name: player_name)
        end
      end
    end

    data["knockout_slots"].each do |slot|
      Match.find_or_create_by!(tournament: tournament, bracket_slot: slot["bracket_slot"]) do |m|
        m.phase = slot["phase"]
        m.status = "scheduled"
      end
    end

    tournament
  end
end
