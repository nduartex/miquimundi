class CreateMatchPredictions < ActiveRecord::Migration[8.0]
  def change
    create_table :match_predictions do |t|
      t.references :quiniela, null: false, foreign_key: true
      t.references :match, null: false, foreign_key: true
      t.integer :pred_home
      t.integer :pred_away
      t.references :penalty_qualifier, null: true, foreign_key: { to_table: :teams }
      t.integer :points_earned, default: 0, null: false

      t.timestamps
    end
  end
end
