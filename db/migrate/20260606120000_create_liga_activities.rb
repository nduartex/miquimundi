class CreateLigaActivities < ActiveRecord::Migration[8.0]
  def change
    create_table :liga_activities do |t|
      t.references :liga, null: false, foreign_key: true, index: false
      t.references :user, foreign_key: true
      t.string :action, null: false
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end
    add_index :liga_activities, [ :liga_id, :created_at ]
  end
end
