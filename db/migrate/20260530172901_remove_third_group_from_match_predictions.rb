class RemoveThirdGroupFromMatchPredictions < ActiveRecord::Migration[8.0]
  # Dead column: "best thirds" moved to quinielas.best_third_groups (jsonb).
  # No code reads or writes match_predictions.third_group.
  def change
    remove_column :match_predictions, :third_group, :string
  end
end
