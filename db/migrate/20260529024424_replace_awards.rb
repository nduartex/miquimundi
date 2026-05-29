class ReplaceAwards < ActiveRecord::Migration[8.0]
  def change
    %i[award_predictions tournament_results].each do |table|
      remove_reference table, :top_scorer_player, foreign_key: { to_table: :players }
      remove_reference table, :top_assists_player, foreign_key: { to_table: :players }
      add_reference table, :balon_oro_player,  null: true, foreign_key: { to_table: :players }
      add_reference table, :bota_oro_player,   null: true, foreign_key: { to_table: :players }
      add_reference table, :guante_oro_player, null: true, foreign_key: { to_table: :players }
      add_reference table, :young_player,      null: true, foreign_key: { to_table: :players }
      add_reference table, :fair_play_team,    null: true, foreign_key: { to_table: :teams }
    end
  end
end
