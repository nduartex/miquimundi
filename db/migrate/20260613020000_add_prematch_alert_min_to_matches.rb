class AddPrematchAlertMinToMatches < ActiveRecord::Migration[8.0]
  def change
    add_column :matches, :prematch_alert_min, :integer
  end
end
