class AddLateDeadlineAtToTournaments < ActiveRecord::Migration[8.0]
  def change
    add_column :tournaments, :late_deadline_at, :datetime
  end
end
