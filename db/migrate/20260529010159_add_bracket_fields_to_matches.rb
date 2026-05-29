class AddBracketFieldsToMatches < ActiveRecord::Migration[8.0]
  def change
    add_column :matches, :match_number, :integer
    add_column :matches, :home_label, :string
    add_column :matches, :away_label, :string
    add_column :matches, :advances_to, :string
  end
end
