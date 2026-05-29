class SwitchEmailToUsername < ActiveRecord::Migration[8.0]
  def up
    add_column :users, :username, :string
    add_column :users, :access_token, :string
    # Throwaway dev/test users created under the old email scheme (cascade clears their quinielas).
    execute "TRUNCATE users CASCADE"
    change_column_null :users, :username, false
    change_column_null :users, :access_token, false
    add_index :users, :username, unique: true
    add_index :users, :access_token, unique: true
    remove_column :users, :email
  end

  def down
    add_column :users, :email, :string
    remove_column :users, :username
    remove_column :users, :access_token
  end
end
