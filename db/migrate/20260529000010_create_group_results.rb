class CreateGroupResults < ActiveRecord::Migration[8.0]
  def change
    create_table :group_results do |t|
      t.references :group, null: false, foreign_key: true
      t.references :first_team, null: false, foreign_key: { to_table: :teams }
      t.references :second_team, null: false, foreign_key: { to_table: :teams }

      t.timestamps
    end
  end
end
