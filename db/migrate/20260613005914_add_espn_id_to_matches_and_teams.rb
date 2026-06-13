class AddEspnIdToMatchesAndTeams < ActiveRecord::Migration[8.0]
  def change
    add_column :matches, :espn_id, :string
    add_index :matches, :espn_id, unique: true
    add_column :teams, :espn_id, :string
    add_index :teams, :espn_id, unique: true
  end
end
