class CreateSolidQueueTables < ActiveRecord::Migration[8.0]
  def change
    create_table :solid_queue_jobs, id: :bigint do |t|
      t.string :queue_name, null: false
      t.integer :priority, default: 0, null: false
      t.text :command, null: false
      t.bigint :active_job_id
      t.string :scheduled_at
      t.string :finished_at
      t.integer :concurrency_key
      t.string :tag
      t.integer :process_id
      t.integer :worker_id
      t.integer :failed_attempts, default: 0
      t.string :last_error
      t.datetime :created_at, null: false
      t.datetime :updated_at, null: false

      t.index [:queue_name, :finished_at]
      t.index [:scheduled_at], where: "finished_at IS NULL"
      t.index [:active_job_id]
      t.index [:concurrency_key], where: "finished_at IS NULL"
      t.index [:tag], where: "finished_at IS NULL"
      t.index [:process_id]
      t.index [:worker_id]
    end

    create_table :solid_queue_scheduled_executions, id: :bigint do |t|
      t.bigint :job_id, null: false
      t.string :queue_name, null: false
      t.integer :priority, default: 0, null: false
      t.datetime :scheduled_at, null: false
      t.datetime :created_at, null: false
      t.datetime :updated_at, null: false

      t.foreign_key :solid_queue_jobs, column: :job_id, on_delete: :cascade
      t.index [:queue_name, :scheduled_at]
    end

    create_table :solid_queue_processes, id: :bigint do |t|
      t.string :kind, null: false
      t.datetime :last_heartbeat_at, null: false
      t.datetime :created_at, null: false
      t.datetime :updated_at, null: false

      t.index [:kind, :last_heartbeat_at]
    end

    create_table :solid_queue_workers, id: :bigint do |t|
      t.bigint :process_id, null: false
      t.string :worker_name, null: false
      t.integer :queue_size, default: 0, null: false
      t.datetime :last_heartbeat_at, null: false
      t.datetime :created_at, null: false
      t.datetime :updated_at, null: false

      t.foreign_key :solid_queue_processes, column: :process_id, on_delete: :cascade
      t.index [:process_id]
      t.index [:worker_name]
    end

    create_table :solid_queue_pauses, id: :bigint do |t|
      t.string :queue_name, null: false
      t.datetime :paused_at, null: false
      t.datetime :created_at, null: false
      t.datetime :updated_at, null: false

      t.index [:queue_name], unique: true
    end

    create_table :solid_queue_recurring_tasks, id: :bigint do |t|
      t.string :key, null: false
      t.string :schedule, null: false
      t.string :command, null: false
      t.datetime :last_enqueued_at
      t.datetime :created_at, null: false
      t.datetime :updated_at, null: false

      t.index [:key], unique: true
    end
  end
end

