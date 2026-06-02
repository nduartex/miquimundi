class AddPositionToPlayers < ActiveRecord::Migration[8.0]
  def change
    add_column :players, :position, :string
  end
end
