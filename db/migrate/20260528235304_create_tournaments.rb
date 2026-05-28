class CreateTournaments < ActiveRecord::Migration[8.0]
  def change
    create_table :tournaments do |t|
      t.string :name
      t.integer :year
      t.datetime :locked_at

      t.timestamps
    end
  end
end
