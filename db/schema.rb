# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2026_06_13_013316) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "achievements", force: :cascade do |t|
    t.bigint "quiniela_id", null: false
    t.string "key", null: false
    t.datetime "earned_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["quiniela_id", "key"], name: "index_achievements_on_quiniela_id_and_key", unique: true
    t.index ["quiniela_id"], name: "index_achievements_on_quiniela_id"
  end

  create_table "award_predictions", force: :cascade do |t|
    t.bigint "quiniela_id", null: false
    t.integer "points_earned", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "balon_oro_player_id"
    t.bigint "bota_oro_player_id"
    t.bigint "guante_oro_player_id"
    t.bigint "young_player_id"
    t.bigint "fair_play_team_id"
    t.index ["balon_oro_player_id"], name: "index_award_predictions_on_balon_oro_player_id"
    t.index ["bota_oro_player_id"], name: "index_award_predictions_on_bota_oro_player_id"
    t.index ["fair_play_team_id"], name: "index_award_predictions_on_fair_play_team_id"
    t.index ["guante_oro_player_id"], name: "index_award_predictions_on_guante_oro_player_id"
    t.index ["quiniela_id"], name: "index_award_predictions_on_quiniela_id"
    t.index ["young_player_id"], name: "index_award_predictions_on_young_player_id"
  end

  create_table "goals", force: :cascade do |t|
    t.bigint "match_id", null: false
    t.bigint "team_id", null: false
    t.bigint "player_id"
    t.string "player_name", null: false
    t.string "minute"
    t.boolean "own_goal", default: false, null: false
    t.boolean "penalty", default: false, null: false
    t.integer "sort_order", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["match_id", "sort_order"], name: "index_goals_on_match_id_and_sort_order"
    t.index ["match_id"], name: "index_goals_on_match_id"
    t.index ["player_id"], name: "index_goals_on_player_id"
    t.index ["team_id"], name: "index_goals_on_team_id"
  end

  create_table "group_predictions", force: :cascade do |t|
    t.bigint "quiniela_id", null: false
    t.bigint "group_id", null: false
    t.bigint "first_team_id"
    t.bigint "second_team_id"
    t.integer "points_earned", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "third_team_id"
    t.bigint "fourth_team_id"
    t.index ["first_team_id"], name: "index_group_predictions_on_first_team_id"
    t.index ["fourth_team_id"], name: "index_group_predictions_on_fourth_team_id"
    t.index ["group_id"], name: "index_group_predictions_on_group_id"
    t.index ["quiniela_id"], name: "index_group_predictions_on_quiniela_id"
    t.index ["second_team_id"], name: "index_group_predictions_on_second_team_id"
    t.index ["third_team_id"], name: "index_group_predictions_on_third_team_id"
  end

  create_table "group_results", force: :cascade do |t|
    t.bigint "group_id", null: false
    t.bigint "first_team_id", null: false
    t.bigint "second_team_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["first_team_id"], name: "index_group_results_on_first_team_id"
    t.index ["group_id"], name: "index_group_results_on_group_id"
    t.index ["second_team_id"], name: "index_group_results_on_second_team_id"
  end

  create_table "group_standings", force: :cascade do |t|
    t.bigint "group_id", null: false
    t.bigint "team_id", null: false
    t.integer "played", default: 0, null: false
    t.integer "wins", default: 0, null: false
    t.integer "draws", default: 0, null: false
    t.integer "losses", default: 0, null: false
    t.integer "goals_for", default: 0, null: false
    t.integer "goals_against", default: 0, null: false
    t.integer "goal_difference", default: 0, null: false
    t.integer "points", default: 0, null: false
    t.integer "rank"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["group_id", "team_id"], name: "index_group_standings_on_group_id_and_team_id", unique: true
    t.index ["group_id"], name: "index_group_standings_on_group_id"
    t.index ["team_id"], name: "index_group_standings_on_team_id"
  end

  create_table "groups", force: :cascade do |t|
    t.bigint "tournament_id", null: false
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["tournament_id"], name: "index_groups_on_tournament_id"
  end

  create_table "liga_activities", force: :cascade do |t|
    t.bigint "liga_id", null: false
    t.bigint "user_id"
    t.string "action", null: false
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["liga_id", "created_at"], name: "index_liga_activities_on_liga_id_and_created_at"
    t.index ["user_id"], name: "index_liga_activities_on_user_id"
  end

  create_table "liga_memberships", force: :cascade do |t|
    t.bigint "liga_id", null: false
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["liga_id", "user_id"], name: "index_liga_memberships_on_liga_id_and_user_id", unique: true
    t.index ["liga_id"], name: "index_liga_memberships_on_liga_id"
    t.index ["user_id"], name: "index_liga_memberships_on_user_id"
  end

  create_table "ligas", force: :cascade do |t|
    t.string "name", null: false
    t.string "invite_code", null: false
    t.integer "max_players", null: false
    t.bigint "creator_id", null: false
    t.bigint "tournament_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "has_prize", default: false, null: false
    t.integer "prize_pot"
    t.index ["creator_id"], name: "index_ligas_on_creator_id"
    t.index ["invite_code"], name: "index_ligas_on_invite_code", unique: true
    t.index ["tournament_id"], name: "index_ligas_on_tournament_id"
  end

  create_table "match_predictions", force: :cascade do |t|
    t.bigint "quiniela_id", null: false
    t.bigint "match_id", null: false
    t.integer "pred_home"
    t.integer "pred_away"
    t.integer "points_earned", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "penalty_qualifier_id"
    t.index ["match_id"], name: "index_match_predictions_on_match_id"
    t.index ["penalty_qualifier_id"], name: "index_match_predictions_on_penalty_qualifier_id"
    t.index ["quiniela_id"], name: "index_match_predictions_on_quiniela_id"
  end

  create_table "matches", force: :cascade do |t|
    t.bigint "tournament_id", null: false
    t.string "phase"
    t.bigint "home_team_id"
    t.bigint "away_team_id"
    t.integer "home_goals"
    t.integer "away_goals"
    t.bigint "penalty_winner_id"
    t.datetime "kickoff_at"
    t.string "status"
    t.string "bracket_slot"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "match_number"
    t.string "home_label"
    t.string "away_label"
    t.string "advances_to"
    t.string "espn_id"
    t.index ["away_team_id"], name: "index_matches_on_away_team_id"
    t.index ["espn_id"], name: "index_matches_on_espn_id", unique: true
    t.index ["home_team_id"], name: "index_matches_on_home_team_id"
    t.index ["penalty_winner_id"], name: "index_matches_on_penalty_winner_id"
    t.index ["tournament_id", "home_team_id", "away_team_id"], name: "index_group_matches_on_pairing", unique: true, where: "((phase)::text = 'group'::text)"
    t.index ["tournament_id"], name: "index_matches_on_tournament_id"
  end

  create_table "players", force: :cascade do |t|
    t.bigint "team_id", null: false
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "position"
    t.index ["team_id"], name: "index_players_on_team_id"
  end

  create_table "quinielas", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "tournament_id", null: false
    t.integer "total_points", default: 0, null: false
    t.integer "exact_hits", default: 0, null: false
    t.integer "match_hits", default: 0, null: false
    t.datetime "submitted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "best_third_groups", default: [], null: false
    t.string "share_token", null: false
    t.datetime "first_part_completed_at"
    t.integer "worst_rank"
    t.boolean "late", default: false, null: false
    t.index ["share_token"], name: "index_quinielas_on_share_token", unique: true
    t.index ["tournament_id"], name: "index_quinielas_on_tournament_id"
    t.index ["user_id"], name: "index_quinielas_on_user_id"
  end

  create_table "solid_cable_messages", force: :cascade do |t|
    t.binary "channel", null: false
    t.binary "payload", null: false
    t.datetime "created_at", null: false
    t.bigint "channel_hash", null: false
    t.index ["channel"], name: "index_solid_cable_messages_on_channel"
    t.index ["channel_hash"], name: "index_solid_cable_messages_on_channel_hash"
    t.index ["created_at"], name: "index_solid_cable_messages_on_created_at"
  end

  create_table "solid_cache_entries", force: :cascade do |t|
    t.binary "key", null: false
    t.binary "value", null: false
    t.datetime "created_at", null: false
    t.bigint "key_hash", null: false
    t.integer "byte_size", null: false
    t.index ["byte_size"], name: "index_solid_cache_entries_on_byte_size"
    t.index ["key_hash", "byte_size"], name: "index_solid_cache_entries_on_key_hash_and_byte_size"
    t.index ["key_hash"], name: "index_solid_cache_entries_on_key_hash", unique: true
  end

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.string "concurrency_key", null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.text "error"
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "queue_name", null: false
    t.string "class_name", null: false
    t.text "arguments"
    t.integer "priority", default: 0, null: false
    t.string "active_job_id"
    t.datetime "scheduled_at"
    t.datetime "finished_at"
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.string "queue_name", null: false
    t.datetime "created_at", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.bigint "supervisor_id"
    t.integer "pid", null: false
    t.string "hostname"
    t.text "metadata"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "task_key", null: false
    t.datetime "run_at", null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", force: :cascade do |t|
    t.string "key", null: false
    t.string "schedule", null: false
    t.string "command", limit: 2048
    t.string "class_name"
    t.text "arguments"
    t.string "queue_name"
    t.integer "priority", default: 0
    t.boolean "static", default: true, null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.datetime "scheduled_at", null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.string "key", null: false
    t.integer "value", default: 1, null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
  end

  create_table "teams", force: :cascade do |t|
    t.bigint "group_id", null: false
    t.string "name"
    t.string "code"
    t.string "flag_emoji"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "espn_id"
    t.index ["espn_id"], name: "index_teams_on_espn_id", unique: true
    t.index ["group_id"], name: "index_teams_on_group_id"
  end

  create_table "tournament_results", force: :cascade do |t|
    t.bigint "tournament_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "qualified_third_codes", default: [], null: false
    t.bigint "balon_oro_player_id"
    t.bigint "bota_oro_player_id"
    t.bigint "guante_oro_player_id"
    t.bigint "young_player_id"
    t.bigint "fair_play_team_id"
    t.index ["balon_oro_player_id"], name: "index_tournament_results_on_balon_oro_player_id"
    t.index ["bota_oro_player_id"], name: "index_tournament_results_on_bota_oro_player_id"
    t.index ["fair_play_team_id"], name: "index_tournament_results_on_fair_play_team_id"
    t.index ["guante_oro_player_id"], name: "index_tournament_results_on_guante_oro_player_id"
    t.index ["tournament_id"], name: "index_tournament_results_on_tournament_id"
    t.index ["young_player_id"], name: "index_tournament_results_on_young_player_id"
  end

  create_table "tournaments", force: :cascade do |t|
    t.string "name"
    t.integer "year"
    t.datetime "locked_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "late_deadline_at"
  end

  create_table "users", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "onboarded_at"
    t.bigint "favorite_team_id"
    t.string "username", null: false
    t.string "access_token", null: false
    t.string "pin_digest"
    t.index ["access_token"], name: "index_users_on_access_token", unique: true
    t.index ["favorite_team_id"], name: "index_users_on_favorite_team_id"
    t.index ["username"], name: "index_users_on_username", unique: true
  end

  add_foreign_key "achievements", "quinielas"
  add_foreign_key "award_predictions", "players", column: "balon_oro_player_id"
  add_foreign_key "award_predictions", "players", column: "bota_oro_player_id"
  add_foreign_key "award_predictions", "players", column: "guante_oro_player_id"
  add_foreign_key "award_predictions", "players", column: "young_player_id"
  add_foreign_key "award_predictions", "quinielas"
  add_foreign_key "award_predictions", "teams", column: "fair_play_team_id"
  add_foreign_key "goals", "matches"
  add_foreign_key "goals", "players"
  add_foreign_key "goals", "teams"
  add_foreign_key "group_predictions", "groups"
  add_foreign_key "group_predictions", "quinielas"
  add_foreign_key "group_predictions", "teams", column: "first_team_id"
  add_foreign_key "group_predictions", "teams", column: "fourth_team_id"
  add_foreign_key "group_predictions", "teams", column: "second_team_id"
  add_foreign_key "group_predictions", "teams", column: "third_team_id"
  add_foreign_key "group_results", "groups"
  add_foreign_key "group_results", "teams", column: "first_team_id"
  add_foreign_key "group_results", "teams", column: "second_team_id"
  add_foreign_key "group_standings", "groups"
  add_foreign_key "group_standings", "teams"
  add_foreign_key "groups", "tournaments"
  add_foreign_key "liga_activities", "ligas"
  add_foreign_key "liga_activities", "users"
  add_foreign_key "liga_memberships", "ligas"
  add_foreign_key "liga_memberships", "users"
  add_foreign_key "ligas", "tournaments"
  add_foreign_key "ligas", "users", column: "creator_id"
  add_foreign_key "match_predictions", "matches"
  add_foreign_key "match_predictions", "quinielas"
  add_foreign_key "match_predictions", "teams", column: "penalty_qualifier_id"
  add_foreign_key "matches", "teams", column: "away_team_id"
  add_foreign_key "matches", "teams", column: "home_team_id"
  add_foreign_key "matches", "teams", column: "penalty_winner_id"
  add_foreign_key "matches", "tournaments"
  add_foreign_key "players", "teams"
  add_foreign_key "quinielas", "tournaments"
  add_foreign_key "quinielas", "users"
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "teams", "groups"
  add_foreign_key "tournament_results", "players", column: "balon_oro_player_id"
  add_foreign_key "tournament_results", "players", column: "bota_oro_player_id"
  add_foreign_key "tournament_results", "players", column: "guante_oro_player_id"
  add_foreign_key "tournament_results", "players", column: "young_player_id"
  add_foreign_key "tournament_results", "teams", column: "fair_play_team_id"
  add_foreign_key "tournament_results", "tournaments"
  add_foreign_key "users", "teams", column: "favorite_team_id"
end
