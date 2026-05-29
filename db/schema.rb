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

ActiveRecord::Schema[8.0].define(version: 2026_05_29_022416) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "award_predictions", force: :cascade do |t|
    t.bigint "quiniela_id", null: false
    t.bigint "top_scorer_player_id"
    t.bigint "top_assists_player_id"
    t.integer "points_earned", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["quiniela_id"], name: "index_award_predictions_on_quiniela_id"
    t.index ["top_assists_player_id"], name: "index_award_predictions_on_top_assists_player_id"
    t.index ["top_scorer_player_id"], name: "index_award_predictions_on_top_scorer_player_id"
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

  create_table "groups", force: :cascade do |t|
    t.bigint "tournament_id", null: false
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["tournament_id"], name: "index_groups_on_tournament_id"
  end

  create_table "match_predictions", force: :cascade do |t|
    t.bigint "quiniela_id", null: false
    t.bigint "match_id", null: false
    t.integer "pred_home"
    t.integer "pred_away"
    t.bigint "penalty_qualifier_id"
    t.integer "points_earned", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "third_group"
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
    t.index ["away_team_id"], name: "index_matches_on_away_team_id"
    t.index ["home_team_id"], name: "index_matches_on_home_team_id"
    t.index ["penalty_winner_id"], name: "index_matches_on_penalty_winner_id"
    t.index ["tournament_id"], name: "index_matches_on_tournament_id"
  end

  create_table "players", force: :cascade do |t|
    t.bigint "team_id", null: false
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
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
    t.index ["tournament_id"], name: "index_quinielas_on_tournament_id"
    t.index ["user_id"], name: "index_quinielas_on_user_id"
  end

  create_table "teams", force: :cascade do |t|
    t.bigint "group_id", null: false
    t.string "name"
    t.string "code"
    t.string "flag_emoji"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["group_id"], name: "index_teams_on_group_id"
  end

  create_table "tournament_results", force: :cascade do |t|
    t.bigint "tournament_id", null: false
    t.bigint "top_scorer_player_id"
    t.bigint "top_assists_player_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "qualified_third_codes", default: [], null: false
    t.index ["top_assists_player_id"], name: "index_tournament_results_on_top_assists_player_id"
    t.index ["top_scorer_player_id"], name: "index_tournament_results_on_top_scorer_player_id"
    t.index ["tournament_id"], name: "index_tournament_results_on_tournament_id"
  end

  create_table "tournaments", force: :cascade do |t|
    t.string "name"
    t.integer "year"
    t.datetime "locked_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "users", force: :cascade do |t|
    t.string "email"
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "onboarded_at"
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "award_predictions", "players", column: "top_assists_player_id"
  add_foreign_key "award_predictions", "players", column: "top_scorer_player_id"
  add_foreign_key "award_predictions", "quinielas"
  add_foreign_key "group_predictions", "groups"
  add_foreign_key "group_predictions", "quinielas"
  add_foreign_key "group_predictions", "teams", column: "first_team_id"
  add_foreign_key "group_predictions", "teams", column: "fourth_team_id"
  add_foreign_key "group_predictions", "teams", column: "second_team_id"
  add_foreign_key "group_predictions", "teams", column: "third_team_id"
  add_foreign_key "group_results", "groups"
  add_foreign_key "group_results", "teams", column: "first_team_id"
  add_foreign_key "group_results", "teams", column: "second_team_id"
  add_foreign_key "groups", "tournaments"
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
  add_foreign_key "teams", "groups"
  add_foreign_key "tournament_results", "players", column: "top_assists_player_id"
  add_foreign_key "tournament_results", "players", column: "top_scorer_player_id"
  add_foreign_key "tournament_results", "tournaments"
end
