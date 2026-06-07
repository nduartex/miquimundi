module LigasHelper
  LIGA_ACTIVITY_ICONS = {
    "created"           => "party-popper",
    "joined"            => "user-plus",
    "left"              => "user-minus",
    "expelled"          => "user-x",
    "renamed"           => "square-pen",
    "cupo_changed"      => "users",
    "prize_enabled"     => "coins",
    "prize_disabled"    => "coins",
    "prize_pot_changed" => "coins"
  }.freeze

  def liga_activity_icon(activity)
    LIGA_ACTIVITY_ICONS.fetch(activity.action, "clipboard-list")
  end

  # Spanish sentence for a feed entry, built only from the metadata snapshot
  # (jsonb keys come back as strings) so no user join is ever needed.
  def liga_activity_text(activity)
    m = activity.metadata
    actor = m["actor_name"]
    case activity.action
    when "created"           then "#{actor} creó la liga"
    when "joined"            then "#{actor} se unió a la liga"
    when "left"              then "#{actor} salió de la liga"
    when "expelled"          then "#{actor} expulsó a #{m["target_name"]}"
    when "renamed"           then "#{actor} cambió el nombre de «#{m["from"]}» a «#{m["to"]}»"
    when "cupo_changed"      then "#{actor} cambió el cupo de #{m["from"]} a #{m["to"]}"
    when "prize_enabled"     then "#{actor} activó el premio (pozo: #{number_with_delimiter(m["pot"])})"
    when "prize_disabled"    then "#{actor} desactivó el premio"
    when "prize_pot_changed" then "#{actor} cambió el pozo de #{number_with_delimiter(m["from"])} a #{number_with_delimiter(m["to"])}"
    end
  end
end
