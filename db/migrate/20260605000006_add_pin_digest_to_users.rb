class AddPinDigestToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :pin_digest, :string
  end
end
