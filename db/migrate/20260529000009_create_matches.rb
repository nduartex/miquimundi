class CreateMatches < ActiveRecord::Migration[8.0]
  def change
    create_table :matches do |t|
      t.references :tournament, null: false, foreign_key: true
      t.string :phase
      t.references :home_team, null: true, foreign_key: { to_table: :teams }
      t.references :away_team, null: true, foreign_key: { to_table: :teams }
      t.integer :home_goals
      t.integer :away_goals
      t.references :penalty_winner, null: true, foreign_key: { to_table: :teams }
      t.datetime :kickoff_at
      t.string :status
      t.string :bracket_slot

      t.timestamps
    end
  end
end
