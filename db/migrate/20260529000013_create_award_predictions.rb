class CreateAwardPredictions < ActiveRecord::Migration[8.0]
  def change
    create_table :award_predictions do |t|
      t.references :quiniela, null: false, foreign_key: true
      t.references :top_scorer_player, null: true, foreign_key: { to_table: :players }
      t.references :top_assists_player, null: true, foreign_key: { to_table: :players }
      t.integer :points_earned, default: 0, null: false

      t.timestamps
    end
  end
end
