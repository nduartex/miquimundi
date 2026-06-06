class CreateLigas < ActiveRecord::Migration[8.0]
  def change
    create_table :ligas do |t|
      t.string :name, null: false
      t.string :invite_code, null: false
      t.integer :max_players, null: false
      t.references :creator, null: false, foreign_key: { to_table: :users }
      t.references :tournament, null: false, foreign_key: true
      t.timestamps
    end
    add_index :ligas, :invite_code, unique: true

    create_table :liga_memberships do |t|
      t.references :liga, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.timestamps
    end
    add_index :liga_memberships, [ :liga_id, :user_id ], unique: true
  end
end
