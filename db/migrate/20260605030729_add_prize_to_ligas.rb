class AddPrizeToLigas < ActiveRecord::Migration[8.0]
  def change
    add_column :ligas, :has_prize, :boolean, null: false, default: false
    add_column :ligas, :prize_pot, :integer
  end
end
