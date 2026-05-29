module QuinielasHelper
  # Payload for the "best thirds" picker: lets the client show each group's
  # current 3rd-place team (which changes as the user reorders the group).
  #   teams:  id => { name, flag }
  #   groups: "A" => groupId
  def thirds_payload(tournament)
    teams = {}
    groups = {}
    tournament.groups.includes(:teams).order(:name).each do |group|
      group.teams.each { |t| teams[t.id] = { name: t.name, flag: t.flag_url } }
      groups[group.name] = group.id
    end
    { teams: teams, groups: groups }
  end

  # All players as a searchable dataset for the awards typeahead:
  # [{ id, name, country, flag }]
  def players_dataset(tournament)
    Player.joins(team: :group)
          .where(groups: { tournament_id: tournament.id })
          .includes(:team)
          .order(:name)
          .map { |p| { id: p.id, name: p.name, country: p.team.name, flag: p.team.flag_url } }
  end

  # All national teams as a searchable dataset for the favorite-team picker.
  def teams_dataset(tournament)
    tournament.groups.includes(:teams).order(:name).flat_map(&:teams)
              .sort_by(&:name)
              .map { |t| { id: t.id, name: t.name, country: "", flag: t.flag_url } }
  end

  # Ranked team ids 1st..4th for a group: saved prediction order padded with
  # any remaining teams so it always has all 4.
  def ranked_group_team_ids(group, quiniela)
    gp = quiniela.group_predictions.detect { |p| p.group_id == group.id }
    ranked = gp ? gp.ranked_team_ids : []
    remaining = group.teams.map(&:id) - ranked
    (ranked + remaining).first(4)
  end
end
