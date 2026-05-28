class CreateTeams < ActiveRecord::Migration[8.0]
  def change
    create_table :teams do |t|
      t.references :group, null: false, foreign_key: true
      t.string :name
      t.string :code
      t.string :flag_emoji

      t.timestamps
    end
  end
end
