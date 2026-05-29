class AddFavoriteTeamToUsers < ActiveRecord::Migration[8.0]
  def change
    add_reference :users, :favorite_team, null: true, foreign_key: { to_table: :teams }
  end
end
