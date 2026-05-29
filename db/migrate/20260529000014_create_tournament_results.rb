class CreateTournamentResults < ActiveRecord::Migration[8.0]
  def change
    create_table :tournament_results do |t|
      t.references :tournament, null: false, foreign_key: true
      t.references :top_scorer_player, null: true, foreign_key: { to_table: :players }
      t.references :top_assists_player, null: true, foreign_key: { to_table: :players }

      t.timestamps
    end
  end
end
