class CreateAchievements < ActiveRecord::Migration[8.0]
  def change
    create_table :achievements do |t|
      t.references :quiniela, null: false, foreign_key: true
      t.string :key, null: false
      t.datetime :earned_at, null: false
      t.timestamps
    end
    add_index :achievements, [ :quiniela_id, :key ], unique: true
  end
end
