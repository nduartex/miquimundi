module QuinielasHelper
  # Builds the JSON payload the client-side bracket engine needs to resolve
  # every knockout slot from the user's own predictions:
  #   teams:   id => { name, flag, code }
  #   groups:  "A" => { id:, teams: [ranked team ids] }
  #   matches: [{ id, n, slot, phase, advancesTo, home: feeder, away: feeder }]
  # where a feeder is one of:
  #   { kind: "pos", group: "A", pos: 1 }     # 1st of group A
  #   { kind: "third", groups: ["A","B",...] } # candidate thirds
  #   { kind: "winner", match: 73 }            # winner of match 73
  #   { kind: "loser",  match: 101 }           # loser of match 101
  #   { kind: "label",  text: "…" }            # unresolved fallback text
  def bracket_payload(tournament, quiniela)
    teams = {}
    groups = {}

    tournament.groups.includes(:teams).order(:name).each do |group|
      group.teams.each do |t|
        teams[t.id] = { name: t.name, flag: t.flag_url, code: t.code }
      end
      groups[group.name] = { id: group.id, teams: ranked_group_team_ids(group, quiniela) }
    end

    matches = tournament.matches.knockout.ordered.map do |m|
      {
        id: m.id, n: m.match_number, slot: m.bracket_slot, phase: m.phase,
        advancesTo: m.advances_to.present? ? m.advances_to.delete("M").to_i : nil,
        home: parse_feeder(m.home_label),
        away: parse_feeder(m.away_label)
      }
    end

    { teams: teams, groups: groups, matches: matches }
  end

  private

  # Ranked team ids 1st..4th for a group: the saved prediction order, padded
  # with any remaining group teams so it always has all 4.
  def ranked_group_team_ids(group, quiniela)
    gp = quiniela.group_predictions.detect { |p| p.group_id == group.id }
    ranked = gp ? gp.ranked_team_ids : []
    remaining = group.teams.map(&:id) - ranked
    (ranked + remaining).first(4)
  end

  def parse_feeder(label)
    case label.to_s
    when /\A([1-4])([A-L])\z/ then { kind: "pos", group: Regexp.last_match(2), pos: Regexp.last_match(1).to_i }
    when /\A3º\s*(.+)\z/      then { kind: "third", groups: Regexp.last_match(1).split("/").map(&:strip) }
    when /\AGan\.\s*(\d+)\z/  then { kind: "winner", match: Regexp.last_match(1).to_i }
    when /\APerd\.\s*(\d+)\z/ then { kind: "loser", match: Regexp.last_match(1).to_i }
    else { kind: "label", text: label.to_s }
    end
  end
end
