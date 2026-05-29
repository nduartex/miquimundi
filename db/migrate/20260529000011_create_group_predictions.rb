class CreateGroupPredictions < ActiveRecord::Migration[8.0]
  def change
    create_table :group_predictions do |t|
      t.references :quiniela, null: false, foreign_key: true
      t.references :group, null: false, foreign_key: true
      t.references :first_team, null: true, foreign_key: { to_table: :teams }
      t.references :second_team, null: true, foreign_key: { to_table: :teams }
      t.integer :points_earned, default: 0, null: false

      t.timestamps
    end
  end
end
