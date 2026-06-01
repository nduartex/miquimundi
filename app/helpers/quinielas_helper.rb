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

  # Player-award fields in display order (Fair Play is a team, handled apart).
  PREDICTION_AWARDS = [
    ["Balón de Oro",  :balon_oro_player],
    ["Bota de Oro",   :bota_oro_player],
    ["Guante de Oro", :guante_oro_player],
    ["Mejor joven",   :young_player]
  ].freeze

  # Data for the phase-1 "Mi predicción" share card, embedded as JSON and drawn
  # on a canvas by the share-card Stimulus controller. Emoji flags (the user's
  # explicit choice) render as real flags on the device that generates the card.
  #   { title, username, userFlag, groups: [{name, first, second}], thirds: [],
  #     awards: [{label, name, flag}] }   where a team brief is {name, flag} or nil.
  def prediction_card_data(quiniela)
    tournament = quiniela.tournament
    preds = quiniela.group_predictions
                    .includes(:first_team, :second_team, :third_team)
                    .index_by(&:group_id)
    ordered_groups = tournament.groups.order(:name).to_a

    groups = ordered_groups.map do |group|
      gp = preds[group.id]
      { name: group.name,
        first:  team_brief(gp&.first_team),
        second: team_brief(gp&.second_team) }
    end

    picked = Array(quiniela.best_third_groups)
    thirds = ordered_groups.select { |g| picked.include?(g.name) }
                           .map { |g| team_brief(preds[g.id]&.third_team) }
                           .compact

    { title: "MI PREDICCIÓN",
      username: quiniela.user.display_name,
      userFlag: quiniela.user.favorite_team&.flag_emoji,
      groups: groups,
      thirds: thirds,
      awards: prediction_award_briefs(quiniela.award_prediction) }
  end

  # Data for the "Mis logros" share card (9:16 image), embedded as JSON and drawn
  # by the achievements-share Stimulus controller. Only unlocked achievements.
  #   { title, username, userFlag, count, total, achievements: [{emoji, name, description}] }
  def achievements_card_data(quiniela)
    earned = quiniela.achievements.pluck(:key)
    items = AchievementCatalog::ALL.select { |e| earned.include?(e.key) }
                                   .map { |e| { emoji: e.emoji, name: e.name, description: e.description } }
    { title: "MIS LOGROS",
      username: quiniela.user.display_name,
      userFlag: quiniela.user.favorite_team&.flag_emoji,
      count: items.size,
      total: AchievementCatalog::ALL.size,
      achievements: items }
  end

  private

  def team_brief(team)
    return nil unless team
    { name: team.name, flag: team.flag_emoji }
  end

  def prediction_award_briefs(award)
    return [] unless award

    briefs = PREDICTION_AWARDS.filter_map do |label, field|
      player = award.public_send(field)
      next unless player
      { label: label, name: player.name, flag: player.team&.flag_emoji }
    end
    if (team = award.fair_play_team)
      briefs << { label: "Fair Play", name: team.name, flag: team.flag_emoji }
    end
    briefs
  end
end
