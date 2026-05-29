class AddBestThirds < ActiveRecord::Migration[8.0]
  def change
    # Group letters the user nominates as qualifying best thirds (exactly 8).
    add_column :quinielas, :best_third_groups, :jsonb, default: [], null: false
    # Real team codes that actually qualified as best thirds (loaded via results).
    add_column :tournament_results, :qualified_third_codes, :jsonb, default: [], null: false
  end
end
