class AddRankingAndBracketPicks < ActiveRecord::Migration[8.0]
  def change
    add_reference :group_predictions, :third_team, null: true, foreign_key: { to_table: :teams }
    add_reference :group_predictions, :fourth_team, null: true, foreign_key: { to_table: :teams }
    add_column :match_predictions, :third_group, :string
  end
end
