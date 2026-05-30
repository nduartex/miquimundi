class AddShareTokenToQuinielas < ActiveRecord::Migration[8.0]
  def up
    add_column :quinielas, :share_token, :string
    Quiniela.reset_column_information
    Quiniela.where(share_token: nil).find_each do |q|
      q.update_columns(share_token: SecureRandom.base58(24))
    end
    add_index :quinielas, :share_token, unique: true
    change_column_null :quinielas, :share_token, false
  end

  def down
    remove_column :quinielas, :share_token
  end
end
