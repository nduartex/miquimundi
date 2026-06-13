class CalendarController < ApplicationController
  FIXTURES_PATH = Rails.root.join("config", "fixtures_2026.json")

  DAYS = %w[domingo lunes martes miércoles jueves viernes sábado].freeze
  MONTHS = %w[ene feb mar abr may jun jul ago sep oct nov dic].freeze

  PHASE_LABELS = {
    "group" => "Fase de grupos",
    "round_32" => "Dieciseisavos de final",
    "round_16" => "Octavos de final",
    "quarter" => "Cuartos de final",
    "semi" => "Semifinales",
    "third_place" => "Tercer puesto",
    "final" => "Final"
  }.freeze

  helper_method :phase_label

  # Public match calendar. Reads the static fixtures file, groups matches by
  # their official date and orders each day by kickoff (knockout matches without
  # a confirmed time fall back to their match number). Team names and flags come
  # from the teams table (joined on iso2), so the roster is the single source of
  # truth. Times are rendered as UTC and converted to the visitor's timezone
  # client-side (local_time_controller).
  def show
    @days = load_matches
      .group_by { |m| m["date"] }
      .sort_by { |date, _| date }
      .map do |date, matches|
        {
          date: date,
          label: day_label(date),
          matches: matches.sort_by { |m| m["kickoff_utc"] || format("%03d", m["match_number"].to_i) }
        }
      end

    # Day to jump to on load: today's matches, else the next upcoming day, else
    # the last day once the tournament is over. @today is separate: it only marks
    # the day that is *actually* today (the "Hoy" badge), which may not exist.
    @today = Date.current.iso8601
    @focus_date = @days.map { |d| d[:date] }.find { |d| d >= @today } || @days.last&.dig(:date)
  end

  private

  # Fixtures carry only the team's iso2 code; resolve name + flag from the teams
  # table so the calendar reflects the real roster. Falls back to whatever the
  # fixtures provide if a team isn't found (e.g. data not yet seeded).
  # Each entry also gets its DB match (synced from ESPN) attached under
  # "record" so the view can show live scores, status and goal events.
  def load_matches
    teams = team_lookup
    group_records, knockout_records = match_lookups
    JSON.parse(File.read(FIXTURES_PATH)).fetch("matches", []).each do |match|
      %w[home away].each do |side|
        info = match[side]
        next if info.blank?
        team = teams[info["iso2"]]
        next unless team
        info["name"] = team.name
        info["flag_url"] = team.flag_url
      end
      match["record"] = find_record(match, teams, group_records, knockout_records)
    end
  end

  # Group matches are joined by home team + kickoff proximity (the fixture file
  # and ESPN agree on the official schedule; ±24h absorbs any drift). Knockouts
  # are joined by their official match number.
  def find_record(entry, teams, group_records, knockout_records)
    if entry["phase"] == "group"
      home = teams[entry.dig("home", "iso2")]
      return nil unless home && entry["kickoff_utc"].present?
      kickoff = Time.zone.parse(entry["kickoff_utc"])
      (group_records[home.id] || []).find { |m| m.kickoff_at && (m.kickoff_at - kickoff).abs < 24.hours }
    else
      knockout_records[entry["match_number"]]
    end
  end

  def match_lookups
    matches = Tournament.current&.matches
                        &.includes(:home_team, :away_team, goals: :team)&.to_a || []
    grouped = matches.select { |m| m.phase == "group" }.group_by(&:home_team_id)
    knockouts = matches.reject { |m| m.phase == "group" }.index_by(&:match_number)
    [grouped, knockouts]
  end

  # iso2 ("mx") => Team, derived from Team::ISO2 (FIFA code => iso2).
  def team_lookup
    Team.all.each_with_object({}) do |team, lookup|
      iso = Team::ISO2[team.code]
      lookup[iso] = team if iso
    end
  end

  def phase_label(phase)
    PHASE_LABELS.fetch(phase, phase)
  end

  # "jueves 11 jun" — built manually to avoid depending on I18n locale config.
  def day_label(date)
    d = Date.iso8601(date)
    "#{DAYS[d.wday]} #{d.day} #{MONTHS[d.month - 1]}"
  end
end
