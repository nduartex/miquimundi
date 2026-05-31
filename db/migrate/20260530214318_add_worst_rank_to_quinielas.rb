class AddWorstRankToQuinielas < ActiveRecord::Migration[8.0]
  def change
    add_column :quinielas, :worst_rank, :integer
  end
end
