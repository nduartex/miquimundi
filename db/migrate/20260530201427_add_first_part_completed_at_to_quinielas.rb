class AddFirstPartCompletedAtToQuinielas < ActiveRecord::Migration[8.0]
  def up
    add_column :quinielas, :first_part_completed_at, :datetime
    # Quinielas already submitted under the old flow shouldn't see the milestone
    # modal on their next save — treat them as already celebrated.
    execute <<~SQL
      UPDATE quinielas SET first_part_completed_at = submitted_at WHERE submitted_at IS NOT NULL
    SQL
  end

  def down
    remove_column :quinielas, :first_part_completed_at
  end
end
