class AddLateToQuinielas < ActiveRecord::Migration[8.0]
  def change
    # Stamped at save time when the first part is completed during the late
    # window. Persisted (instead of derived from locked_at) so later changes to
    # the tournament dates can never reclassify a quiniela retroactively.
    add_column :quinielas, :late, :boolean, default: false, null: false
  end
end
