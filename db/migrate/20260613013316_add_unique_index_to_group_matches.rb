class AddUniqueIndexToGroupMatches < ActiveRecord::Migration[8.0]
  # Backs Espn::SyncService#map_match's create_or_find_by!: without it, two
  # overlapping syncs could insert the same group fixture twice (knockouts are
  # excluded — they share placeholder nil teams until the bracket resolves).
  def change
    add_index :matches, %i[tournament_id home_team_id away_team_id],
              unique: true, where: "phase = 'group'",
              name: "index_group_matches_on_pairing"
  end
end
