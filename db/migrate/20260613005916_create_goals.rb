class CreateGoals < ActiveRecord::Migration[8.0]
  def change
    create_table :goals do |t|
      t.references :match, null: false, foreign_key: true
      t.references :team, null: false, foreign_key: true
      t.references :player, foreign_key: true
      t.string :player_name, null: false
      t.string :minute
      t.boolean :own_goal, default: false, null: false
      t.boolean :penalty, default: false, null: false
      t.integer :sort_order, default: 0, null: false
      t.timestamps
    end
    add_index :goals, %i[match_id sort_order]
  end
end
