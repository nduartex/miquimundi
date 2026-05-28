class CreateQuinielas < ActiveRecord::Migration[8.0]
  def change
    create_table :quinielas do |t|
      t.references :user, null: false, foreign_key: true
      t.references :tournament, null: false, foreign_key: true
      t.integer :total_points, default: 0, null: false
      t.integer :exact_hits, default: 0, null: false
      t.integer :match_hits, default: 0, null: false
      t.datetime :submitted_at

      t.timestamps
    end
  end
end
