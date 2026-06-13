class CreateGroupStandings < ActiveRecord::Migration[8.0]
  def change
    create_table :group_standings do |t|
      t.references :group, null: false, foreign_key: true
      t.references :team, null: false, foreign_key: true
      t.integer :played, default: 0, null: false
      t.integer :wins, default: 0, null: false
      t.integer :draws, default: 0, null: false
      t.integer :losses, default: 0, null: false
      t.integer :goals_for, default: 0, null: false
      t.integer :goals_against, default: 0, null: false
      t.integer :goal_difference, default: 0, null: false
      t.integer :points, default: 0, null: false
      t.integer :rank
      t.timestamps
    end
    add_index :group_standings, %i[group_id team_id], unique: true
  end
end
