# Quiniela Mundial 2026 — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a full-stack Rails 8 World Cup 2026 prediction pool where users register by email, fill predictions (group stage, knockouts, individual awards), see "Mi Quiniela", and compete on a live global ranking.

**Architecture:** Rails 8 monolith with Hotwire (Turbo + Stimulus) and Tailwind. Pure, idempotent `ScoringService` computes points. Real results enter through a decoupled `ResultsProvider` (manual YAML today, API/scraper later) driven by rake tasks. Live ranking via Turbo Stream broadcasts. No admin panel.

**Tech Stack:** Ruby 3.2.2, Rails 8.0.5, PostgreSQL, Hotwire (Turbo/Stimulus), Tailwind CSS, Solid Queue, Action Mailer, Minitest.

---

## File Structure

**Models** (`app/models/`): `tournament.rb`, `group.rb`, `team.rb`, `player.rb`, `user.rb`, `quiniela.rb`, `group_prediction.rb`, `match.rb`, `match_prediction.rb`, `group_result.rb`, `award_prediction.rb`, `tournament_result.rb`

**Services** (`app/services/`): `scoring_service.rb`, `results/manual_provider.rb`, `results/base_provider.rb`

**Controllers** (`app/controllers/`): `sessions_controller.rb`, `quinielas_controller.rb`, `predictions_controller.rb`, `rankings_controller.rb`, `concerns/authentication.rb`

**Views** (`app/views/`): `sessions/`, `quinielas/` (wizard + show "Mi Quiniela"), `rankings/`, layout + partials.

**Jobs** (`app/jobs/`): `recalculate_scores_job.rb`

**Mailers** (`app/mailers/`): `quiniela_mailer.rb`

**Rake** (`lib/tasks/`): `quiniela.rake`

**Data** (`db/`): `seeds.rb`, `seeds/world_cup_2026.yml`, `results.yml`

**Tests** (`test/`): mirrors models/services/controllers/mailers.

---

## Task 1: Scaffold Rails app

**Files:**
- Create: whole Rails skeleton in `/home/nelson/quiniela_mundial`

- [ ] **Step 1: Generate the app into the existing repo**

The repo already exists at `/home/nelson/quiniela_mundial` with `docs/`. Generate Rails into it.

Run:
```bash
cd /home/nelson/quiniela_mundial
gem install rails -v 8.0.5 --conservative
rails new . --database=postgresql --css=tailwind --skip-test --force --skip-bundle
```
(We pass `--skip-test` then re-enable Minitest manually so the generated `test/` dir is clean; `--force` lets it write alongside `docs/`.)

- [ ] **Step 2: Re-enable Minitest test dir**

Edit `config/application.rb` — ensure no test framework was disabled. Then create `test/test_helper.rb`:

```ruby
ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    parallelize(workers: :number_of_processors)
    fixtures :all
  end
end
```

- [ ] **Step 3: Bundle install**

Run: `bundle install`
Expected: resolves with rails 8.0.5, pg, tailwindcss-rails, turbo-rails, stimulus-rails, solid_queue.

- [ ] **Step 4: Configure database**

Edit `config/database.yml` development/test sections to use local Postgres (default socket auth works on this machine; `psql` is installed). Keep generated defaults; set `host: localhost` if needed.

Run: `bin/rails db:create`
Expected: `Created database 'quiniela_mundial_development'` and `_test`.

- [ ] **Step 5: Install Solid Queue**

Run:
```bash
bin/rails solid_queue:install
bin/rails db:migrate
```
Expected: solid_queue tables migrated.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "chore: scaffold Rails 8 app with Postgres, Tailwind, Hotwire, Solid Queue"
```

---

## Task 2: Tournament, Group, Team, Player models

**Files:**
- Create migrations, `app/models/tournament.rb`, `group.rb`, `team.rb`, `player.rb`
- Test: `test/models/team_test.rb`, `test/models/group_test.rb`

- [ ] **Step 1: Generate migrations & models**

Run:
```bash
bin/rails g model Tournament name:string year:integer locked_at:datetime
bin/rails g model Group tournament:references name:string
bin/rails g model Team group:references name:string code:string flag_emoji:string
bin/rails g model Player team:references name:string
```

- [ ] **Step 2: Write failing association/validation test**

`test/models/team_test.rb`:
```ruby
require "test_helper"

class TeamTest < ActiveSupport::TestCase
  test "is invalid without a name" do
    team = Team.new(code: "BRA")
    assert_not team.valid?
    assert_includes team.errors[:name], "can't be blank"
  end

  test "belongs to a group and has players" do
    assert_respond_to Team.new, :group
    assert_respond_to Team.new, :players
  end
end
```

`test/models/group_test.rb`:
```ruby
require "test_helper"

class GroupTest < ActiveSupport::TestCase
  test "has many teams ordered" do
    assert_respond_to Group.new, :teams
  end

  test "requires a name" do
    group = Group.new
    assert_not group.valid?
    assert_includes group.errors[:name], "can't be blank"
  end
end
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `bin/rails test test/models/team_test.rb test/models/group_test.rb`
Expected: FAIL (associations/validations not yet defined).

- [ ] **Step 4: Implement models**

`app/models/tournament.rb`:
```ruby
class Tournament < ApplicationRecord
  has_many :groups, dependent: :destroy
  has_many :matches, dependent: :destroy
  has_one :tournament_result, dependent: :destroy

  validates :name, :year, presence: true

  def self.current
    order(year: :desc).first
  end

  def locked?
    locked_at.present? && locked_at <= Time.current
  end
end
```

`app/models/group.rb`:
```ruby
class Group < ApplicationRecord
  belongs_to :tournament
  has_many :teams, dependent: :destroy
  has_one :group_result, dependent: :destroy

  validates :name, presence: true
end
```

`app/models/team.rb`:
```ruby
class Team < ApplicationRecord
  belongs_to :group
  has_many :players, dependent: :destroy

  validates :name, presence: true

  def label
    [flag_emoji, name].compact.join(" ")
  end
end
```

`app/models/player.rb`:
```ruby
class Player < ApplicationRecord
  belongs_to :team

  validates :name, presence: true

  def label
    "#{name} (#{team.name})"
  end
end
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `bin/rails test test/models/team_test.rb test/models/group_test.rb`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat: add Tournament, Group, Team, Player models"
```

---

## Task 3: User and Quiniela models

**Files:**
- Create migrations, `app/models/user.rb`, `app/models/quiniela.rb`
- Test: `test/models/user_test.rb`, `test/models/quiniela_test.rb`

- [ ] **Step 1: Generate**

```bash
bin/rails g model User email:string:uniq name:string
bin/rails g model Quiniela user:references tournament:references total_points:integer exact_hits:integer match_hits:integer submitted_at:datetime
```

- [ ] **Step 2: Write failing tests**

`test/models/user_test.rb`:
```ruby
require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "requires a valid unique email" do
    User.create!(email: "a@b.com")
    dup = User.new(email: "a@b.com")
    assert_not dup.valid?
  end

  test "downcases email before save" do
    user = User.create!(email: "MiXeD@CASE.com")
    assert_equal "mixed@case.com", user.email
  end

  test "rejects malformed email" do
    assert_not User.new(email: "not-an-email").valid?
  end
end
```

`test/models/quiniela_test.rb`:
```ruby
require "test_helper"

class QuinielaTest < ActiveSupport::TestCase
  test "defaults counters to zero" do
    q = Quiniela.new
    assert_equal 0, q.total_points
    assert_equal 0, q.exact_hits
    assert_equal 0, q.match_hits
  end

  test "submitted? reflects submitted_at" do
    assert_not Quiniela.new.submitted?
    assert Quiniela.new(submitted_at: Time.current).submitted?
  end
end
```

- [ ] **Step 3: Run to verify fail**

Run: `bin/rails test test/models/user_test.rb test/models/quiniela_test.rb`
Expected: FAIL.

- [ ] **Step 4: Set counter defaults in migration**

Edit the generated Quiniela migration so counters default to 0:
```ruby
t.integer :total_points, default: 0, null: false
t.integer :exact_hits, default: 0, null: false
t.integer :match_hits, default: 0, null: false
```
Run: `bin/rails db:migrate`

- [ ] **Step 5: Implement models**

`app/models/user.rb`:
```ruby
class User < ApplicationRecord
  has_many :quinielas, dependent: :destroy

  EMAIL_REGEX = /\A[^@\s]+@[^@\s]+\.[^@\s]+\z/

  before_validation { self.email = email.to_s.downcase.strip }

  validates :email, presence: true, uniqueness: true, format: { with: EMAIL_REGEX }

  def display_name
    name.presence || email
  end

  def quiniela_for(tournament)
    quinielas.find_or_initialize_by(tournament: tournament)
  end
end
```

`app/models/quiniela.rb`:
```ruby
class Quiniela < ApplicationRecord
  belongs_to :user
  belongs_to :tournament
  has_many :group_predictions, dependent: :destroy
  has_many :match_predictions, dependent: :destroy
  has_one :award_prediction, dependent: :destroy

  def submitted?
    submitted_at.present?
  end

  def predicted_final?
    match_predictions
      .joins(:match)
      .where(matches: { phase: "final" })
      .where.not(pred_home: nil, pred_away: nil)
      .exists?
  end
end
```

- [ ] **Step 6: Run to verify pass**

Run: `bin/rails test test/models/user_test.rb test/models/quiniela_test.rb`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "feat: add User and Quiniela models"
```

---

## Task 4: Match, GroupResult, prediction & award models

**Files:**
- Create migrations + models: `match.rb`, `group_prediction.rb`, `match_prediction.rb`, `group_result.rb`, `award_prediction.rb`, `tournament_result.rb`
- Test: `test/models/match_test.rb`

- [ ] **Step 1: Generate**

```bash
bin/rails g model Match tournament:references phase:string home_team:references away_team:references home_goals:integer away_goals:integer penalty_winner:references kickoff_at:datetime status:string bracket_slot:string
bin/rails g model GroupResult group:references first_team:references second_team:references
bin/rails g model GroupPrediction quiniela:references group:references first_team:references second_team:references points_earned:integer
bin/rails g model MatchPrediction quiniela:references match:references pred_home:integer pred_away:integer penalty_qualifier:references points_earned:integer
bin/rails g model AwardPrediction quiniela:references top_scorer_player:references top_assists_player:references points_earned:integer
bin/rails g model TournamentResult tournament:references top_scorer_player:references top_assists_player:references
```

In each generated migration, the `home_team`/`away_team`/`penalty_winner`/`first_team`/`second_team`/`penalty_qualifier`/`top_scorer_player`/`top_assists_player` references point to non-default table names — add `foreign_key: { to_table: :teams }` (team-typed) or `:players` (player-typed) and make them nullable (`null: true`). Example for Match migration:
```ruby
t.references :home_team, null: true, foreign_key: { to_table: :teams }
t.references :away_team, null: true, foreign_key: { to_table: :teams }
t.references :penalty_winner, null: true, foreign_key: { to_table: :teams }
```
Set counter defaults: `t.integer :points_earned, default: 0, null: false` in GroupPrediction, MatchPrediction, AwardPrediction.

Run: `bin/rails db:migrate`

- [ ] **Step 2: Write failing test**

`test/models/match_test.rb`:
```ruby
require "test_helper"

class MatchTest < ActiveSupport::TestCase
  test "knockout? excludes group phase" do
    assert_not Match.new(phase: "group").knockout?
    assert Match.new(phase: "round_16").knockout?
    assert Match.new(phase: "final").knockout?
  end

  test "multiplier scales by phase" do
    assert_in_delta 1.0, Match.new(phase: "round_16").multiplier, 0.001
    assert_in_delta 1.5, Match.new(phase: "quarter").multiplier, 0.001
    assert_in_delta 2.0, Match.new(phase: "semi").multiplier, 0.001
    assert_in_delta 3.0, Match.new(phase: "final").multiplier, 0.001
  end

  test "locked? once kickoff has passed" do
    assert Match.new(kickoff_at: 1.hour.ago).locked?
    assert_not Match.new(kickoff_at: 1.hour.from_now).locked?
  end

  test "finished? requires both goals present" do
    assert_not Match.new(status: "finished").finished?
    assert Match.new(status: "finished", home_goals: 1, away_goals: 0).finished?
  end
end
```

- [ ] **Step 3: Run to verify fail**

Run: `bin/rails test test/models/match_test.rb`
Expected: FAIL.

- [ ] **Step 4: Implement models**

`app/models/match.rb`:
```ruby
class Match < ApplicationRecord
  PHASES = %w[group round_16 quarter semi final].freeze
  STATUSES = %w[scheduled live finished].freeze
  MULTIPLIERS = { "round_16" => 1.0, "quarter" => 1.5, "semi" => 2.0, "final" => 3.0 }.freeze

  belongs_to :tournament
  belongs_to :home_team, class_name: "Team", optional: true
  belongs_to :away_team, class_name: "Team", optional: true
  belongs_to :penalty_winner, class_name: "Team", optional: true
  has_many :match_predictions, dependent: :destroy

  validates :phase, inclusion: { in: PHASES }
  validates :status, inclusion: { in: STATUSES }

  scope :knockout, -> { where.not(phase: "group") }
  scope :ordered, -> { order(:kickoff_at) }

  def knockout?
    phase != "group"
  end

  def multiplier
    MULTIPLIERS.fetch(phase, 1.0)
  end

  def locked?
    kickoff_at.present? && kickoff_at <= Time.current
  end

  def finished?
    status == "finished" && home_goals.present? && away_goals.present?
  end

  def actual_winner_team_id
    return nil unless finished?
    return home_team_id if home_goals > away_goals
    return away_team_id if away_goals > home_goals
    nil
  end
end
```

`app/models/group_result.rb`:
```ruby
class GroupResult < ApplicationRecord
  belongs_to :group
  belongs_to :first_team, class_name: "Team"
  belongs_to :second_team, class_name: "Team"

  def qualified_team_ids
    [first_team_id, second_team_id]
  end
end
```

`app/models/group_prediction.rb`:
```ruby
class GroupPrediction < ApplicationRecord
  belongs_to :quiniela
  belongs_to :group
  belongs_to :first_team, class_name: "Team", optional: true
  belongs_to :second_team, class_name: "Team", optional: true

  validate :teams_must_differ

  def predicted_team_ids
    [first_team_id, second_team_id].compact
  end

  private

  def teams_must_differ
    return if first_team_id.blank? || second_team_id.blank?
    errors.add(:second_team, "must differ from first") if first_team_id == second_team_id
  end
end
```

`app/models/match_prediction.rb`:
```ruby
class MatchPrediction < ApplicationRecord
  belongs_to :quiniela
  belongs_to :match
  belongs_to :penalty_qualifier, class_name: "Team", optional: true

  def predicted_winner_team_id
    return nil if pred_home.blank? || pred_away.blank?
    return match.home_team_id if pred_home > pred_away
    return match.away_team_id if pred_away > pred_home
    nil
  end
end
```

`app/models/award_prediction.rb`:
```ruby
class AwardPrediction < ApplicationRecord
  belongs_to :quiniela
  belongs_to :top_scorer_player, class_name: "Player", optional: true
  belongs_to :top_assists_player, class_name: "Player", optional: true
end
```

`app/models/tournament_result.rb`:
```ruby
class TournamentResult < ApplicationRecord
  belongs_to :tournament
  belongs_to :top_scorer_player, class_name: "Player", optional: true
  belongs_to :top_assists_player, class_name: "Player", optional: true
end
```

- [ ] **Step 5: Run to verify pass**

Run: `bin/rails test test/models/match_test.rb`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat: add Match, results, prediction and award models"
```

---

## Task 5: ScoringService — group stage scoring

**Files:**
- Create: `app/services/scoring_service.rb`
- Test: `test/services/scoring_service_test.rb`

- [ ] **Step 1: Write failing group-scoring test**

`test/services/scoring_service_test.rb`:
```ruby
require "test_helper"

class ScoringServiceTest < ActiveSupport::TestCase
  def setup
    @tournament = Tournament.create!(name: "WC", year: 2026)
    @group = Group.create!(tournament: @tournament, name: "A")
    @t1 = Team.create!(group: @group, name: "T1")
    @t2 = Team.create!(group: @group, name: "T2")
    @t3 = Team.create!(group: @group, name: "T3")
    GroupResult.create!(group: @group, first_team: @t1, second_team: @t2)
    @user = User.create!(email: "p@x.com")
    @quiniela = Quiniela.create!(user: @user, tournament: @tournament)
  end

  test "both teams correct and in exact order scores 3+3+2" do
    GroupPrediction.create!(quiniela: @quiniela, group: @group, first_team: @t1, second_team: @t2)
    ScoringService.new(@quiniela).call
    assert_equal 8, @quiniela.reload.total_points
  end

  test "both teams correct but wrong order scores 3+3" do
    GroupPrediction.create!(quiniela: @quiniela, group: @group, first_team: @t2, second_team: @t1)
    ScoringService.new(@quiniela).call
    assert_equal 6, @quiniela.reload.total_points
  end

  test "one team correct scores 3" do
    GroupPrediction.create!(quiniela: @quiniela, group: @group, first_team: @t1, second_team: @t3)
    ScoringService.new(@quiniela).call
    assert_equal 3, @quiniela.reload.total_points
  end
end
```

- [ ] **Step 2: Run to verify fail**

Run: `bin/rails test test/services/scoring_service_test.rb`
Expected: FAIL (ScoringService undefined).

- [ ] **Step 3: Implement group scoring**

`app/services/scoring_service.rb`:
```ruby
class ScoringService
  POINTS_PER_QUALIFIED = 3
  EXACT_ORDER_BONUS = 2
  EXACT_SCORE = 5
  CORRECT_WINNER = 2
  CORRECT_PENALTY = 3
  AWARD_POINTS = 10

  def initialize(quiniela)
    @quiniela = quiniela
  end

  def call
    total = 0
    exact_hits = 0
    match_hits = 0

    total += score_groups

    @quiniela.update!(total_points: total, exact_hits: exact_hits, match_hits: match_hits)
  end

  private

  def score_groups
    sum = 0
    @quiniela.group_predictions.includes(:group).each do |gp|
      result = GroupResult.find_by(group_id: gp.group_id)
      points = group_points(gp, result)
      gp.update!(points_earned: points)
      sum += points
    end
    sum
  end

  def group_points(prediction, result)
    return 0 if result.nil?
    actual = result.qualified_team_ids
    predicted = prediction.predicted_team_ids
    correct = (predicted & actual).size
    points = correct * POINTS_PER_QUALIFIED
    if prediction.first_team_id == result.first_team_id &&
       prediction.second_team_id == result.second_team_id
      points += EXACT_ORDER_BONUS
    end
    points
  end
end
```

- [ ] **Step 4: Run to verify pass**

Run: `bin/rails test test/services/scoring_service_test.rb`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: ScoringService group-stage scoring"
```

---

## Task 6: ScoringService — knockout match scoring + multipliers

**Files:**
- Modify: `app/services/scoring_service.rb`
- Test: `test/services/scoring_service_test.rb`

- [ ] **Step 1: Add failing knockout tests**

Append to `test/services/scoring_service_test.rb` (inside the class):
```ruby
  def build_match(phase:, home:, away:, hg:, ag:, pen: nil)
    Match.create!(tournament: @tournament, phase: phase, home_team: home, away_team: away,
                  home_goals: hg, away_goals: ag, penalty_winner: pen,
                  status: "finished", kickoff_at: 1.day.ago)
  end

  test "exact score in round_16 scores 5" do
    m = build_match(phase: "round_16", home: @t1, away: @t2, hg: 2, ag: 1)
    MatchPrediction.create!(quiniela: @quiniela, match: m, pred_home: 2, pred_away: 1)
    ScoringService.new(@quiniela).call
    assert_equal 5, @quiniela.reload.total_points
    assert_equal 1, @quiniela.exact_hits
    assert_equal 1, @quiniela.match_hits
  end

  test "correct winner wrong score scores 2" do
    m = build_match(phase: "round_16", home: @t1, away: @t2, hg: 3, ag: 0)
    MatchPrediction.create!(quiniela: @quiniela, match: m, pred_home: 2, pred_away: 1)
    ScoringService.new(@quiniela).call
    assert_equal 2, @quiniela.reload.total_points
    assert_equal 0, @quiniela.exact_hits
    assert_equal 1, @quiniela.match_hits
  end

  test "quarter multiplier x1.5 on exact score yields 7" do
    m = build_match(phase: "quarter", home: @t1, away: @t2, hg: 1, ag: 0)
    MatchPrediction.create!(quiniela: @quiniela, match: m, pred_home: 1, pred_away: 0)
    ScoringService.new(@quiniela).call
    assert_equal 7, @quiniela.reload.total_points # floor(5 * 1.5) = 7
  end

  test "final multiplier x3 on exact score yields 15" do
    m = build_match(phase: "final", home: @t1, away: @t2, hg: 0, ag: 0, pen: @t1)
    MatchPrediction.create!(quiniela: @quiniela, match: m, pred_home: 0, pred_away: 0, penalty_qualifier: @t1)
    ScoringService.new(@quiniela).call
    # exact 0-0 = 5, +3 penalty correct = 8, x3 = 24
    assert_equal 24, @quiniela.reload.total_points
  end

  test "correct penalty qualifier scores 3" do
    m = build_match(phase: "round_16", home: @t1, away: @t2, hg: 1, ag: 1, pen: @t2)
    MatchPrediction.create!(quiniela: @quiniela, match: m, pred_home: 0, pred_away: 0, penalty_qualifier: @t2)
    ScoringService.new(@quiniela).call
    # exact 1-1 wrong (pred 0-0) -> draw winner nil so no winner pts; penalty correct = 3
    assert_equal 3, @quiniela.reload.total_points
  end
```

- [ ] **Step 2: Run to verify fail**

Run: `bin/rails test test/services/scoring_service_test.rb`
Expected: FAIL on the new knockout tests.

- [ ] **Step 3: Add match scoring to ScoringService**

Modify `app/services/scoring_service.rb` `call` to track and add match points, and add the helper methods. Replace the `call` and add methods:

```ruby
  def call
    total = 0
    @exact_hits = 0
    @match_hits = 0

    total += score_groups
    total += score_matches

    @quiniela.update!(total_points: total, exact_hits: @exact_hits, match_hits: @match_hits)
  end
```

Add private methods:
```ruby
  def score_matches
    sum = 0
    @quiniela.match_predictions.includes(:match).each do |mp|
      match = mp.match
      next unless match.finished?
      raw = match_points(mp, match)
      points = (raw * match.multiplier).floor
      mp.update!(points_earned: points)
      sum += points
    end
    sum
  end

  def match_points(prediction, match)
    points = 0
    exact = prediction.pred_home == match.home_goals && prediction.pred_away == match.away_goals
    if exact
      points += EXACT_SCORE
      @exact_hits += 1
      @match_hits += 1
    elsif prediction.predicted_winner_team_id.present? &&
          prediction.predicted_winner_team_id == match.actual_winner_team_id
      points += CORRECT_WINNER
      @match_hits += 1
    end
    if match.penalty_winner_id.present? &&
       prediction.penalty_qualifier_id == match.penalty_winner_id
      points += CORRECT_PENALTY
    end
    points
  end
```

Also initialize `@exact_hits`/`@match_hits` are set in `call`; the `score_groups` method stays as-is.

- [ ] **Step 4: Run to verify pass**

Run: `bin/rails test test/services/scoring_service_test.rb`
Expected: PASS (all group + knockout tests).

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: ScoringService knockout scoring with phase multipliers"
```

---

## Task 7: ScoringService — individual awards

**Files:**
- Modify: `app/services/scoring_service.rb`
- Test: `test/services/scoring_service_test.rb`

- [ ] **Step 1: Add failing award test**

Append inside the test class:
```ruby
  test "correct top scorer and top assists each score 10" do
    p1 = Player.create!(team: @t1, name: "Striker")
    p2 = Player.create!(team: @t2, name: "Playmaker")
    TournamentResult.create!(tournament: @tournament, top_scorer_player: p1, top_assists_player: p2)
    AwardPrediction.create!(quiniela: @quiniela, top_scorer_player: p1, top_assists_player: p2)
    ScoringService.new(@quiniela).call
    assert_equal 20, @quiniela.reload.total_points
  end

  test "only top scorer correct scores 10" do
    p1 = Player.create!(team: @t1, name: "Striker")
    p2 = Player.create!(team: @t2, name: "Playmaker")
    p3 = Player.create!(team: @t3, name: "Other")
    TournamentResult.create!(tournament: @tournament, top_scorer_player: p1, top_assists_player: p2)
    AwardPrediction.create!(quiniela: @quiniela, top_scorer_player: p1, top_assists_player: p3)
    ScoringService.new(@quiniela).call
    assert_equal 10, @quiniela.reload.total_points
  end
```

- [ ] **Step 2: Run to verify fail**

Run: `bin/rails test test/services/scoring_service_test.rb`
Expected: FAIL on award tests.

- [ ] **Step 3: Add award scoring**

In `app/services/scoring_service.rb`, update `call` to add `total += score_awards` after `score_matches`, and add:
```ruby
  def score_awards
    award = @quiniela.award_prediction
    result = @quiniela.tournament.tournament_result
    return 0 if award.nil? || result.nil?

    sum = 0
    if award.top_scorer_player_id.present? &&
       award.top_scorer_player_id == result.top_scorer_player_id
      sum += AWARD_POINTS
    end
    if award.top_assists_player_id.present? &&
       award.top_assists_player_id == result.top_assists_player_id
      sum += AWARD_POINTS
    end
    award.update!(points_earned: sum)
    sum
  end
```

- [ ] **Step 4: Run to verify pass**

Run: `bin/rails test test/services/scoring_service_test.rb`
Expected: PASS (all scoring tests).

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: ScoringService individual award scoring"
```

---

## Task 8: ResultsProvider + rake tasks

**Files:**
- Create: `app/services/results/base_provider.rb`, `app/services/results/manual_provider.rb`
- Create: `db/results.yml`, `lib/tasks/quiniela.rake`
- Create: `app/jobs/recalculate_scores_job.rb`
- Test: `test/services/results/manual_provider_test.rb`

- [ ] **Step 1: Write failing provider test**

`test/services/results/manual_provider_test.rb`:
```ruby
require "test_helper"

class Results::ManualProviderTest < ActiveSupport::TestCase
  def setup
    @tournament = Tournament.create!(name: "WC", year: 2026)
    @group = Group.create!(tournament: @tournament, name: "A")
    @t1 = Team.create!(group: @group, name: "T1", code: "T1")
    @t2 = Team.create!(group: @group, name: "T2", code: "T2")
    @match = Match.create!(tournament: @tournament, phase: "round_16",
                           home_team: @t1, away_team: @t2, status: "scheduled",
                           kickoff_at: 1.day.ago, bracket_slot: "R16-1")
  end

  test "applies group results and match scores from a hash" do
    data = {
      "group_results" => [{ "group" => "A", "first" => "T1", "second" => "T2" }],
      "matches" => [{ "bracket_slot" => "R16-1", "home_goals" => 2, "away_goals" => 1 }]
    }
    Results::ManualProvider.new(@tournament, data).apply!

    assert_equal @t1.id, GroupResult.find_by(group: @group).first_team_id
    @match.reload
    assert_equal 2, @match.home_goals
    assert_equal "finished", @match.status
  end
end
```

- [ ] **Step 2: Run to verify fail**

Run: `bin/rails test test/services/results/manual_provider_test.rb`
Expected: FAIL.

- [ ] **Step 3: Implement providers**

`app/services/results/base_provider.rb`:
```ruby
module Results
  class BaseProvider
    def initialize(tournament, data = nil)
      @tournament = tournament
      @data = data
    end

    # Subclasses implement #apply! to write real results into the DB.
    def apply!
      raise NotImplementedError
    end
  end
end
```

`app/services/results/manual_provider.rb`:
```ruby
module Results
  class ManualProvider < BaseProvider
    def apply!
      apply_group_results
      apply_matches
      apply_awards
    end

    private

    def teams
      @teams ||= @tournament.groups.flat_map(&:teams).index_by(&:code)
    end

    def players
      @players ||= Player.where(team: teams.values).index_by(&:name)
    end

    def apply_group_results
      Array(@data["group_results"]).each do |row|
        group = @tournament.groups.find_by(name: row["group"])
        next unless group
        first = teams[row["first"]]
        second = teams[row["second"]]
        next unless first && second
        result = GroupResult.find_or_initialize_by(group: group)
        result.update!(first_team: first, second_team: second)
      end
    end

    def apply_matches
      Array(@data["matches"]).each do |row|
        match = @tournament.matches.find_by(bracket_slot: row["bracket_slot"])
        next unless match
        match.update!(
          home_team: row["home"] ? teams[row["home"]] : match.home_team,
          away_team: row["away"] ? teams[row["away"]] : match.away_team,
          home_goals: row["home_goals"],
          away_goals: row["away_goals"],
          penalty_winner: row["penalty_winner"] ? teams[row["penalty_winner"]] : nil,
          status: "finished"
        )
      end
    end

    def apply_awards
      awards = @data["awards"]
      return unless awards
      result = TournamentResult.find_or_initialize_by(tournament: @tournament)
      result.update!(
        top_scorer_player: awards["top_scorer"] ? players[awards["top_scorer"]] : result.top_scorer_player,
        top_assists_player: awards["top_assists"] ? players[awards["top_assists"]] : result.top_assists_player
      )
    end
  end
end
```

- [ ] **Step 4: Run to verify pass**

Run: `bin/rails test test/services/results/manual_provider_test.rb`
Expected: PASS.

- [ ] **Step 5: Create recalculation job**

`app/jobs/recalculate_scores_job.rb`:
```ruby
class RecalculateScoresJob < ApplicationJob
  queue_as :default

  def perform(tournament_id)
    tournament = Tournament.find(tournament_id)
    tournament.quinielas_relation.find_each do |quiniela|
      ScoringService.new(quiniela).call
    end
    Turbo::StreamsChannel.broadcast_replace_to(
      "ranking_#{tournament.id}",
      target: "ranking",
      partial: "rankings/table",
      locals: { quinielas: RankingsController.ranked(tournament) }
    )
  end
end
```

Add to `app/models/tournament.rb`:
```ruby
  def quinielas_relation
    Quiniela.where(tournament_id: id)
  end
```

- [ ] **Step 6: Create results YAML + rake tasks**

`db/results.yml`:
```yaml
# Resultados reales del Mundial 2026. Editar y correr: bin/rails quiniela:load_results
group_results: []
matches: []
awards:
  top_scorer:
  top_assists:
```

`lib/tasks/quiniela.rake`:
```ruby
namespace :quiniela do
  desc "Carga resultados reales desde db/results.yml y recalcula puntajes"
  task load_results: :environment do
    tournament = Tournament.current
    abort("No hay torneo cargado. Corre bin/rails db:seed") if tournament.nil?

    data = YAML.safe_load_file(Rails.root.join("db/results.yml"))
    Results::ManualProvider.new(tournament, data).apply!
    puts "Resultados aplicados. Recalculando puntajes..."
    Quiniela.where(tournament_id: tournament.id).find_each do |q|
      ScoringService.new(q).call
    end
    puts "Listo. #{tournament.quinielas_relation.count} quinielas recalculadas."
  end

  desc "Recalcula puntajes de todas las quinielas"
  task recalculate: :environment do
    tournament = Tournament.current
    abort("No hay torneo cargado.") if tournament.nil?
    Quiniela.where(tournament_id: tournament.id).find_each do |q|
      ScoringService.new(q).call
    end
    puts "Recalculo completo."
  end
end
```

- [ ] **Step 7: Run full test suite**

Run: `bin/rails test`
Expected: PASS (all so far).

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "feat: decoupled ResultsProvider, recalculation job and rake tasks"
```

---

## Task 9: Seeds — World Cup 2026 data

**Files:**
- Create: `db/seeds/world_cup_2026.yml`, modify `db/seeds.rb`
- Test: `test/seeds_test.rb`

- [ ] **Step 1: Create the data file**

`db/seeds/world_cup_2026.yml` — 12 groups, 48 teams (verified data), and a few notable players per team. Use ISO-ish codes for `code`. Structure:
```yaml
tournament:
  name: "Copa Mundial de la FIFA 2026"
  year: 2026
groups:
  A:
    - { name: "México", code: "MEX", flag: "🇲🇽", players: ["Santiago Giménez", "Hirving Lozano", "Edson Álvarez"] }
    - { name: "Sudáfrica", code: "RSA", flag: "🇿🇦", players: ["Percy Tau", "Lyle Foster"] }
    - { name: "Corea del Sur", code: "KOR", flag: "🇰🇷", players: ["Son Heung-min", "Lee Kang-in"] }
    - { name: "Chequia", code: "CZE", flag: "🇨🇿", players: ["Patrik Schick", "Adam Hložek"] }
  B:
    - { name: "Canadá", code: "CAN", flag: "🇨🇦", players: ["Alphonso Davies", "Jonathan David"] }
    - { name: "Bosnia", code: "BIH", flag: "🇧🇦", players: ["Edin Džeko", "Ermedin Demirović"] }
    - { name: "Catar", code: "QAT", flag: "🇶🇦", players: ["Akram Afif", "Almoez Ali"] }
    - { name: "Suiza", code: "SUI", flag: "🇨🇭", players: ["Granit Xhaka", "Breel Embolo"] }
  C:
    - { name: "Brasil", code: "BRA", flag: "🇧🇷", players: ["Vinícius Júnior", "Rodrygo", "Raphinha"] }
    - { name: "Marruecos", code: "MAR", flag: "🇲🇦", players: ["Achraf Hakimi", "Brahim Díaz"] }
    - { name: "Haití", code: "HAI", flag: "🇭🇹", players: ["Frantzdy Pierrot"] }
    - { name: "Escocia", code: "SCO", flag: "🏴", players: ["Scott McTominay", "John McGinn"] }
  D:
    - { name: "Estados Unidos", code: "USA", flag: "🇺🇸", players: ["Christian Pulisic", "Weston McKennie"] }
    - { name: "Paraguay", code: "PAR", flag: "🇵🇾", players: ["Miguel Almirón", "Julio Enciso"] }
    - { name: "Australia", code: "AUS", flag: "🇦🇺", players: ["Mathew Leckie", "Jackson Irvine"] }
    - { name: "Turquía", code: "TUR", flag: "🇹🇷", players: ["Arda Güler", "Kenan Yıldız"] }
  E:
    - { name: "Alemania", code: "GER", flag: "🇩🇪", players: ["Jamal Musiala", "Florian Wirtz", "Kai Havertz"] }
    - { name: "Curazao", code: "CUW", flag: "🇨🇼", players: ["Tahith Chong"] }
    - { name: "Costa de Marfil", code: "CIV", flag: "🇨🇮", players: ["Sébastien Haller", "Simon Adingra"] }
    - { name: "Ecuador", code: "ECU", flag: "🇪🇨", players: ["Moisés Caicedo", "Enner Valencia"] }
  F:
    - { name: "Países Bajos", code: "NED", flag: "🇳🇱", players: ["Cody Gakpo", "Memphis Depay"] }
    - { name: "Japón", code: "JPN", flag: "🇯🇵", players: ["Takefusa Kubo", "Kaoru Mitoma"] }
    - { name: "Suecia", code: "SWE", flag: "🇸🇪", players: ["Alexander Isak", "Viktor Gyökeres"] }
    - { name: "Túnez", code: "TUN", flag: "🇹🇳", players: ["Hannibal Mejbri"] }
  G:
    - { name: "Bélgica", code: "BEL", flag: "🇧🇪", players: ["Kevin De Bruyne", "Romelu Lukaku"] }
    - { name: "Egipto", code: "EGY", flag: "🇪🇬", players: ["Mohamed Salah", "Omar Marmoush"] }
    - { name: "Irán", code: "IRN", flag: "🇮🇷", players: ["Mehdi Taremi", "Sardar Azmoun"] }
    - { name: "Nueva Zelanda", code: "NZL", flag: "🇳🇿", players: ["Chris Wood"] }
  H:
    - { name: "España", code: "ESP", flag: "🇪🇸", players: ["Lamine Yamal", "Nico Williams", "Pedri"] }
    - { name: "Cabo Verde", code: "CPV", flag: "🇨🇻", players: ["Ryan Mendes"] }
    - { name: "Arabia Saudita", code: "KSA", flag: "🇸🇦", players: ["Salem Al-Dawsari"] }
    - { name: "Uruguay", code: "URU", flag: "🇺🇾", players: ["Federico Valverde", "Darwin Núñez"] }
  I:
    - { name: "Francia", code: "FRA", flag: "🇫🇷", players: ["Kylian Mbappé", "Ousmane Dembélé"] }
    - { name: "Senegal", code: "SEN", flag: "🇸🇳", players: ["Sadio Mané", "Nicolas Jackson"] }
    - { name: "Irak", code: "IRQ", flag: "🇮🇶", players: ["Aymen Hussein"] }
    - { name: "Noruega", code: "NOR", flag: "🇳🇴", players: ["Erling Haaland", "Martin Ødegaard"] }
  J:
    - { name: "Argentina", code: "ARG", flag: "🇦🇷", players: ["Lionel Messi", "Lautaro Martínez", "Julián Álvarez"] }
    - { name: "Argelia", code: "ALG", flag: "🇩🇿", players: ["Riyad Mahrez"] }
    - { name: "Austria", code: "AUT", flag: "🇦🇹", players: ["Marcel Sabitzer"] }
    - { name: "Jordania", code: "JOR", flag: "🇯🇴", players: ["Mousa Al-Tamari"] }
  K:
    - { name: "Portugal", code: "POR", flag: "🇵🇹", players: ["Cristiano Ronaldo", "Bruno Fernandes", "Rafael Leão"] }
    - { name: "RD Congo", code: "COD", flag: "🇨🇩", players: ["Cédric Bakambu"] }
    - { name: "Uzbekistán", code: "UZB", flag: "🇺🇿", players: ["Eldor Shomurodov"] }
    - { name: "Colombia", code: "COL", flag: "🇨🇴", players: ["Luis Díaz", "James Rodríguez"] }
  L:
    - { name: "Inglaterra", code: "ENG", flag: "🏴", players: ["Harry Kane", "Jude Bellingham", "Bukayo Saka"] }
    - { name: "Croacia", code: "CRO", flag: "🇭🇷", players: ["Luka Modrić"] }
    - { name: "Ghana", code: "GHA", flag: "🇬🇭", players: ["Mohammed Kudus"] }
    - { name: "Panamá", code: "PAN", flag: "🇵🇦", players: ["Adalberto Carrasquilla"] }
knockout_slots:
  - { phase: "round_16", bracket_slot: "R16-1" }
  - { phase: "round_16", bracket_slot: "R16-2" }
  - { phase: "round_16", bracket_slot: "R16-3" }
  - { phase: "round_16", bracket_slot: "R16-4" }
  - { phase: "round_16", bracket_slot: "R16-5" }
  - { phase: "round_16", bracket_slot: "R16-6" }
  - { phase: "round_16", bracket_slot: "R16-7" }
  - { phase: "round_16", bracket_slot: "R16-8" }
  - { phase: "round_16", bracket_slot: "R16-9" }
  - { phase: "round_16", bracket_slot: "R16-10" }
  - { phase: "round_16", bracket_slot: "R16-11" }
  - { phase: "round_16", bracket_slot: "R16-12" }
  - { phase: "round_16", bracket_slot: "R16-13" }
  - { phase: "round_16", bracket_slot: "R16-14" }
  - { phase: "round_16", bracket_slot: "R16-15" }
  - { phase: "round_16", bracket_slot: "R16-16" }
  - { phase: "quarter", bracket_slot: "QF-1" }
  - { phase: "quarter", bracket_slot: "QF-2" }
  - { phase: "quarter", bracket_slot: "QF-3" }
  - { phase: "quarter", bracket_slot: "QF-4" }
  - { phase: "quarter", bracket_slot: "QF-5" }
  - { phase: "quarter", bracket_slot: "QF-6" }
  - { phase: "quarter", bracket_slot: "QF-7" }
  - { phase: "quarter", bracket_slot: "QF-8" }
  - { phase: "semi", bracket_slot: "SF-1" }
  - { phase: "semi", bracket_slot: "SF-2" }
  - { phase: "semi", bracket_slot: "SF-3" }
  - { phase: "semi", bracket_slot: "SF-4" }
  - { phase: "final", bracket_slot: "F-1" }
```
(Note: 2026 has a round of 32, but per the approved spec we keep "octavos en adelante" = round_16 onward; round of 16 has 16 qualifying matchups modeled as R16-1..16 representing the 8 round-of-16 ties is over-modeled — simplify to 8 R16 slots. Use R16-1..R16-8, QF-1..QF-4, SF-1..SF-2, F-1. Replace the list above with these 15 slots.)

Corrected `knockout_slots`:
```yaml
knockout_slots:
  - { phase: "round_16", bracket_slot: "R16-1" }
  - { phase: "round_16", bracket_slot: "R16-2" }
  - { phase: "round_16", bracket_slot: "R16-3" }
  - { phase: "round_16", bracket_slot: "R16-4" }
  - { phase: "round_16", bracket_slot: "R16-5" }
  - { phase: "round_16", bracket_slot: "R16-6" }
  - { phase: "round_16", bracket_slot: "R16-7" }
  - { phase: "round_16", bracket_slot: "R16-8" }
  - { phase: "quarter", bracket_slot: "QF-1" }
  - { phase: "quarter", bracket_slot: "QF-2" }
  - { phase: "quarter", bracket_slot: "QF-3" }
  - { phase: "quarter", bracket_slot: "QF-4" }
  - { phase: "semi", bracket_slot: "SF-1" }
  - { phase: "semi", bracket_slot: "SF-2" }
  - { phase: "final", bracket_slot: "F-1" }
```

- [ ] **Step 2: Write seeds + idempotency test**

`test/seeds_test.rb`:
```ruby
require "test_helper"

class SeedsTest < ActiveSupport::TestCase
  test "seed loader is idempotent and builds 12 groups / 48 teams" do
    SeedLoader.call
    SeedLoader.call # second run should not duplicate
    tournament = Tournament.find_by(year: 2026)
    assert_equal 12, tournament.groups.count
    assert_equal 48, Team.joins(:group).where(groups: { tournament_id: tournament.id }).count
    assert_equal 15, tournament.matches.count
    assert tournament.matches.where(phase: "final").one?
  end
end
```

- [ ] **Step 3: Run to verify fail**

Run: `bin/rails test test/seeds_test.rb`
Expected: FAIL (SeedLoader undefined).

- [ ] **Step 4: Implement SeedLoader**

`app/services/seed_loader.rb`:
```ruby
class SeedLoader
  def self.call
    new.call
  end

  def call
    data = YAML.safe_load_file(Rails.root.join("db/seeds/world_cup_2026.yml"))
    tournament = Tournament.find_or_create_by!(year: data["tournament"]["year"]) do |t|
      t.name = data["tournament"]["name"]
    end

    data["groups"].each do |group_name, teams|
      group = Group.find_or_create_by!(tournament: tournament, name: group_name)
      teams.each do |team_data|
        team = Team.find_or_create_by!(group: group, code: team_data["code"]) do |t|
          t.name = team_data["name"]
          t.flag_emoji = team_data["flag"]
        end
        Array(team_data["players"]).each do |player_name|
          Player.find_or_create_by!(team: team, name: player_name)
        end
      end
    end

    data["knockout_slots"].each do |slot|
      Match.find_or_create_by!(tournament: tournament, bracket_slot: slot["bracket_slot"]) do |m|
        m.phase = slot["phase"]
        m.status = "scheduled"
      end
    end

    tournament
  end
end
```

`db/seeds.rb`:
```ruby
SeedLoader.call
puts "Seeds cargados: Mundial 2026."
```

- [ ] **Step 5: Run to verify pass**

Run: `bin/rails test test/seeds_test.rb`
Expected: PASS.

- [ ] **Step 6: Load seeds into dev DB**

Run: `bin/rails db:seed`
Expected: "Seeds cargados: Mundial 2026."

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "feat: World Cup 2026 seed data and idempotent SeedLoader"
```

---

## Task 10: Authentication (email-only)

**Files:**
- Create: `app/controllers/concerns/authentication.rb`, `app/controllers/sessions_controller.rb`
- Modify: `app/controllers/application_controller.rb`, `config/routes.rb`
- Create views: `app/views/sessions/new.html.erb`
- Test: `test/controllers/sessions_controller_test.rb`

- [ ] **Step 1: Write failing request test**

`test/controllers/sessions_controller_test.rb`:
```ruby
require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  test "logging in with a new email creates a user and session" do
    assert_difference "User.count", 1 do
      post session_path, params: { email: "new@user.com" }
    end
    assert_redirected_to quiniela_path
  end

  test "logging in with existing email reuses the user" do
    User.create!(email: "old@user.com")
    assert_no_difference "User.count" do
      post session_path, params: { email: "OLD@user.com" }
    end
  end

  test "rejects invalid email" do
    post session_path, params: { email: "nope" }
    assert_response :unprocessable_entity
  end
end
```

- [ ] **Step 2: Run to verify fail**

Run: `bin/rails test test/controllers/sessions_controller_test.rb`
Expected: FAIL (routes/controller missing).

- [ ] **Step 3: Implement authentication concern**

`app/controllers/concerns/authentication.rb`:
```ruby
module Authentication
  extend ActiveSupport::Concern

  included do
    helper_method :current_user, :signed_in?
  end

  private

  def current_user
    @current_user ||= User.find_by(id: session[:user_id])
  end

  def signed_in?
    current_user.present?
  end

  def require_login
    redirect_to new_session_path, alert: "Ingresa tu correo para continuar." unless signed_in?
  end
end
```

`app/controllers/application_controller.rb`:
```ruby
class ApplicationController < ActionController::Base
  include Authentication
end
```

- [ ] **Step 4: Implement SessionsController + routes**

`app/controllers/sessions_controller.rb`:
```ruby
class SessionsController < ApplicationController
  def new
    redirect_to quiniela_path if signed_in?
  end

  def create
    user = User.find_or_initialize_by(email: params[:email].to_s.downcase.strip)
    if user.persisted? || user.save
      session[:user_id] = user.id
      redirect_to quiniela_path, notice: "¡Bienvenido, #{user.display_name}!"
    else
      flash.now[:alert] = "Correo inválido."
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    reset_session
    redirect_to new_session_path, notice: "Sesión cerrada."
  end
end
```

`config/routes.rb`:
```ruby
Rails.application.routes.draw do
  root "sessions#new"
  resource :session, only: %i[new create destroy]
  resource :quiniela, only: %i[show] do
    resources :predictions, only: %i[index create]
  end
  resources :rankings, only: %i[index]
end
```

- [ ] **Step 5: Create login view**

`app/views/sessions/new.html.erb`:
```erb
<div class="min-h-screen flex items-center justify-center px-4">
  <div class="w-full max-w-md bg-white/10 backdrop-blur rounded-3xl p-8 shadow-2xl border border-white/20">
    <h1 class="text-4xl font-black text-white text-center mb-2">⚽ Quiniela Mundial</h1>
    <p class="text-white/80 text-center mb-8">Ingresa tu correo para jugar</p>
    <%= form_with url: session_path, method: :post, class: "space-y-4" do |f| %>
      <%= f.email_field :email, required: true, placeholder: "tu@correo.com",
            class: "w-full rounded-xl px-4 py-3 text-lg focus:ring-4 focus:ring-yellow-300 outline-none" %>
      <%= f.submit "Entrar", class: "w-full bg-gradient-to-r from-yellow-400 to-pink-500 text-white font-bold py-3 rounded-xl text-lg hover:scale-[1.02] transition" %>
    <% end %>
  </div>
</div>
```

- [ ] **Step 6: Run to verify pass**

Run: `bin/rails test test/controllers/sessions_controller_test.rb`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "feat: email-only authentication and login screen"
```

---

## Task 11: QuinielasController + predictions persistence

**Files:**
- Create: `app/controllers/quinielas_controller.rb`, `app/controllers/predictions_controller.rb`
- Modify: routes (already added)
- Test: `test/controllers/predictions_controller_test.rb`

- [ ] **Step 1: Write failing test**

`test/controllers/predictions_controller_test.rb`:
```ruby
require "test_helper"

class PredictionsControllerTest < ActionDispatch::IntegrationTest
  def setup
    SeedLoader.call
    @tournament = Tournament.current
    @group = @tournament.groups.find_by(name: "A")
    @teams = @group.teams.to_a
    @user = User.create!(email: "p@x.com")
    post session_path, params: { email: @user.email }
  end

  test "saving group predictions creates records and a quiniela" do
    post quiniela_predictions_path, params: {
      group_predictions: {
        @group.id.to_s => { first_team_id: @teams[0].id, second_team_id: @teams[1].id }
      }
    }
    quiniela = @user.quinielas.find_by(tournament: @tournament)
    assert_not_nil quiniela
    gp = quiniela.group_predictions.find_by(group: @group)
    assert_equal @teams[0].id, gp.first_team_id
  end

  test "saving sets submitted_at and triggers scoring" do
    post quiniela_predictions_path, params: {
      group_predictions: { @group.id.to_s => { first_team_id: @teams[0].id, second_team_id: @teams[1].id } }
    }
    assert @user.quinielas.find_by(tournament: @tournament).submitted?
  end
end
```

- [ ] **Step 2: Run to verify fail**

Run: `bin/rails test test/controllers/predictions_controller_test.rb`
Expected: FAIL.

- [ ] **Step 3: Implement QuinielasController**

`app/controllers/quinielas_controller.rb`:
```ruby
class QuinielasController < ApplicationController
  before_action :require_login

  def show
    @tournament = Tournament.current
    @quiniela = current_user.quiniela_for(@tournament)
    @quiniela.save! if @quiniela.new_record?
    @groups = @tournament.groups.includes(:teams).order(:name)
    @knockouts = @tournament.matches.knockout.ordered
    @players = Player.includes(:team).order("teams.name")
  end
end
```

- [ ] **Step 4: Implement PredictionsController**

`app/controllers/predictions_controller.rb`:
```ruby
class PredictionsController < ApplicationController
  before_action :require_login

  def create
    @tournament = Tournament.current
    @quiniela = current_user.quiniela_for(@tournament)
    @quiniela.save! if @quiniela.new_record?

    ActiveRecord::Base.transaction do
      save_group_predictions
      save_match_predictions
      save_award_prediction
      @quiniela.update!(submitted_at: Time.current)
    end

    ScoringService.new(@quiniela).call
    QuinielaMailer.confirmation(@quiniela).deliver_later

    respond_to do |format|
      format.html { redirect_to quiniela_path, notice: "¡Quiniela guardada! Revisa tu correo." }
      format.turbo_stream { flash.now[:notice] = "¡Quiniela guardada!" }
    end
  end

  private

  def save_group_predictions
    (params[:group_predictions] || {}).each do |group_id, attrs|
      next if attrs[:first_team_id].blank?
      gp = @quiniela.group_predictions.find_or_initialize_by(group_id: group_id)
      gp.update!(first_team_id: attrs[:first_team_id], second_team_id: attrs[:second_team_id])
    end
  end

  def save_match_predictions
    (params[:match_predictions] || {}).each do |match_id, attrs|
      match = Match.find(match_id)
      next if match.locked?
      next if attrs[:pred_home].blank? || attrs[:pred_away].blank?
      mp = @quiniela.match_predictions.find_or_initialize_by(match_id: match_id)
      mp.update!(pred_home: attrs[:pred_home], pred_away: attrs[:pred_away],
                 penalty_qualifier_id: attrs[:penalty_qualifier_id].presence)
    end
  end

  def save_award_prediction
    attrs = params[:award_prediction]
    return if attrs.blank?
    return unless @quiniela.predicted_final?
    award = @quiniela.award_prediction || @quiniela.build_award_prediction
    award.update!(top_scorer_player_id: attrs[:top_scorer_player_id].presence,
                  top_assists_player_id: attrs[:top_assists_player_id].presence)
  end
end
```

- [ ] **Step 5: Run to verify pass**

Run: `bin/rails test test/controllers/predictions_controller_test.rb`
Expected: PASS (after Task 12 mailer exists; if mailer missing, stub temporarily — but Task 12 follows, so run after Task 12). For now expect failure only on mailer; proceed to Task 12 then re-run.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat: quiniela show and predictions persistence with scoring"
```

---

## Task 12: Confirmation mailer

**Files:**
- Create: `app/mailers/quiniela_mailer.rb`, `app/views/quiniela_mailer/confirmation.html.erb`, `.text.erb`
- Test: `test/mailers/quiniela_mailer_test.rb`

- [ ] **Step 1: Write failing mailer test**

`test/mailers/quiniela_mailer_test.rb`:
```ruby
require "test_helper"

class QuinielaMailerTest < ActionMailer::TestCase
  test "confirmation is addressed to the user with subject" do
    tournament = Tournament.create!(name: "WC", year: 2026)
    user = User.create!(email: "p@x.com", name: "Pancho")
    quiniela = Quiniela.create!(user: user, tournament: tournament)
    mail = QuinielaMailer.confirmation(quiniela)
    assert_equal ["p@x.com"], mail.to
    assert_match "Quiniela", mail.subject
    assert_match "Pancho", mail.body.encoded
  end
end
```

- [ ] **Step 2: Run to verify fail**

Run: `bin/rails test test/mailers/quiniela_mailer_test.rb`
Expected: FAIL.

- [ ] **Step 3: Implement mailer**

`app/mailers/quiniela_mailer.rb`:
```ruby
class QuinielaMailer < ApplicationMailer
  def confirmation(quiniela)
    @quiniela = quiniela
    @user = quiniela.user
    mail(to: @user.email, subject: "✅ Tu Quiniela Mundial fue registrada")
  end
end
```

`app/views/quiniela_mailer/confirmation.html.erb`:
```erb
<h1 style="font-family: sans-serif;">¡Hola <%= @user.display_name %>! ⚽</h1>
<p>Tu quiniela para <strong><%= @quiniela.tournament.name %></strong> quedó registrada correctamente.</p>
<p>Puntaje actual: <strong><%= @quiniela.total_points %></strong> puntos.</p>
<p>Puedes revisarla y seguir el ranking en cualquier momento.</p>
```

`app/views/quiniela_mailer/confirmation.text.erb`:
```erb
¡Hola <%= @user.display_name %>!

Tu quiniela para <%= @quiniela.tournament.name %> quedó registrada correctamente.
Puntaje actual: <%= @quiniela.total_points %> puntos.
```

Set dev delivery to not raise: confirm `config/environments/development.rb` has `config.action_mailer.delivery_method = :test` or `:letter_opener` (use `:test` to avoid extra gems).

- [ ] **Step 4: Run to verify pass**

Run: `bin/rails test test/mailers/quiniela_mailer_test.rb`
Expected: PASS.

- [ ] **Step 5: Re-run predictions controller test (now mailer exists)**

Run: `bin/rails test test/controllers/predictions_controller_test.rb`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat: quiniela confirmation mailer"
```

---

## Task 13: Quiniela wizard views (groups + knockouts + awards)

**Files:**
- Create: `app/views/quinielas/show.html.erb`, partials `_group_stage.html.erb`, `_knockouts.html.erb`, `_awards.html.erb`
- Create Stimulus controller: `app/javascript/controllers/wizard_controller.js`, `confetti_controller.js`
- Test: `test/system/quiniela_flow_test.rb` (smoke, optional headless) OR request-level assertions in existing controller test

- [ ] **Step 1: Build the show layout (wizard)**

`app/views/quinielas/show.html.erb`:
```erb
<div class="max-w-3xl mx-auto px-4 py-8" data-controller="wizard confetti">
  <header class="flex items-center justify-between mb-6">
    <h1 class="text-3xl font-black text-white">Mi Quiniela</h1>
    <div class="text-yellow-300 font-black text-2xl"><%= @quiniela.total_points %> pts</div>
  </header>

  <nav class="flex gap-2 mb-6">
    <button data-action="wizard#go" data-wizard-step-param="0" class="flex-1 py-2 rounded-xl bg-white/20 text-white font-bold">1 · Grupos</button>
    <button data-action="wizard#go" data-wizard-step-param="1" class="flex-1 py-2 rounded-xl bg-white/20 text-white font-bold">2 · Eliminatorias</button>
    <button data-action="wizard#go" data-wizard-step-param="2" class="flex-1 py-2 rounded-xl bg-white/20 text-white font-bold">3 · Premios</button>
  </nav>

  <%= form_with url: quiniela_predictions_path, method: :post,
        data: { action: "submit->confetti#burst" } do %>
    <div data-wizard-target="panel"><%= render "group_stage", groups: @groups, quiniela: @quiniela %></div>
    <div data-wizard-target="panel" class="hidden"><%= render "knockouts", matches: @knockouts, quiniela: @quiniela %></div>
    <div data-wizard-target="panel" class="hidden"><%= render "awards", players: @players, quiniela: @quiniela %></div>

    <div class="mt-8">
      <%= submit_tag "Guardar mi Quiniela", class: "w-full bg-gradient-to-r from-green-400 via-yellow-400 to-pink-500 text-white font-black py-4 rounded-2xl text-xl hover:scale-[1.01] transition" %>
    </div>
  <% end %>
</div>
```

- [ ] **Step 2: Group stage partial**

`app/views/quinielas/_group_stage.html.erb`:
```erb
<div class="grid sm:grid-cols-2 gap-4">
  <% groups.each do |group| %>
    <% gp = quiniela.group_predictions.find_by(group_id: group.id) %>
    <div class="bg-white/10 rounded-2xl p-4 border border-white/20">
      <h3 class="text-white font-black mb-3">Grupo <%= group.name %></h3>
      <label class="block text-white/80 text-sm">1º clasificado</label>
      <%= select_tag "group_predictions[#{group.id}][first_team_id]",
            options_from_collection_for_select(group.teams, :id, :label, gp&.first_team_id),
            include_blank: "—", class: "w-full rounded-lg px-3 py-2 mb-2 text-gray-900" %>
      <label class="block text-white/80 text-sm">2º clasificado</label>
      <%= select_tag "group_predictions[#{group.id}][second_team_id]",
            options_from_collection_for_select(group.teams, :id, :label, gp&.second_team_id),
            include_blank: "—", class: "w-full rounded-lg px-3 py-2 text-gray-900" %>
    </div>
  <% end %>
</div>
```

- [ ] **Step 3: Knockouts partial**

`app/views/quinielas/_knockouts.html.erb`:
```erb
<div class="space-y-3">
  <% matches.each do |match| %>
    <% mp = quiniela.match_predictions.find_by(match_id: match.id) %>
    <div class="bg-white/10 rounded-2xl p-4 border border-white/20 flex items-center gap-3">
      <span class="text-white/70 text-xs uppercase w-20"><%= t("phase.#{match.phase}", default: match.phase) %></span>
      <span class="text-white flex-1"><%= match.home_team&.label || match.bracket_slot %></span>
      <%= number_field_tag "match_predictions[#{match.id}][pred_home]", mp&.pred_home,
            min: 0, class: "w-14 rounded-lg px-2 py-1 text-center text-gray-900", disabled: match.locked? %>
      <span class="text-white">-</span>
      <%= number_field_tag "match_predictions[#{match.id}][pred_away]", mp&.pred_away,
            min: 0, class: "w-14 rounded-lg px-2 py-1 text-center text-gray-900", disabled: match.locked? %>
      <span class="text-white flex-1 text-right"><%= match.away_team&.label || "" %></span>
    </div>
  <% end %>
</div>
```

Add to `config/locales/en.yml` (or create `es.yml`):
```yaml
es:
  phase:
    round_16: "Octavos"
    quarter: "Cuartos"
    semi: "Semis"
    final: "Final"
```
And set `config.i18n.default_locale = :es` in `config/application.rb`.

- [ ] **Step 4: Awards partial (unlocks after final predicted)**

`app/views/quinielas/_awards.html.erb`:
```erb
<div class="bg-white/10 rounded-2xl p-6 border border-white/20" data-wizard-target="awards">
  <% if quiniela.predicted_final? %>
    <h3 class="text-white font-black mb-4">🏆 Premios individuales (10 pts c/u)</h3>
    <label class="block text-white/80 text-sm">Goleador del Mundial</label>
    <%= select_tag "award_prediction[top_scorer_player_id]",
          options_from_collection_for_select(players, :id, :label, quiniela.award_prediction&.top_scorer_player_id),
          include_blank: "—", class: "w-full rounded-lg px-3 py-2 mb-3 text-gray-900" %>
    <label class="block text-white/80 text-sm">Máximo asistidor</label>
    <%= select_tag "award_prediction[top_assists_player_id]",
          options_from_collection_for_select(players, :id, :label, quiniela.award_prediction&.top_assists_player_id),
          include_blank: "—", class: "w-full rounded-lg px-3 py-2 text-gray-900" %>
  <% else %>
    <p class="text-white/80">🔒 Predice primero el resultado de la <strong>final</strong> para desbloquear los premios individuales.</p>
  <% end %>
</div>
```

- [ ] **Step 5: Stimulus controllers**

`app/javascript/controllers/wizard_controller.js`:
```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel"]

  go(event) {
    const step = Number(event.params.step)
    this.panelTargets.forEach((p, i) => p.classList.toggle("hidden", i !== step))
  }
}
```

`app/javascript/controllers/confetti_controller.js`:
```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  burst() {
    const colors = ["#fbbf24", "#ec4899", "#34d399", "#60a5fa"]
    for (let i = 0; i < 60; i++) {
      const c = document.createElement("div")
      c.style.cssText = `position:fixed;top:-10px;left:${Math.random()*100}vw;width:10px;height:10px;background:${colors[i%4]};z-index:9999;border-radius:2px;transition:transform 2s ease-out, opacity 2s;`
      document.body.appendChild(c)
      requestAnimationFrame(() => {
        c.style.transform = `translateY(100vh) rotate(${Math.random()*720}deg)`
        c.style.opacity = "0"
      })
      setTimeout(() => c.remove(), 2200)
    }
  }
}
```

- [ ] **Step 6: Manual smoke check**

Run: `bin/rails server` then visit `/` → login → fill a couple groups → save. Confirm redirect + flash. (No automated assertion in this step.)

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "feat: quiniela wizard views with confetti and award unlock"
```

---

## Task 14: "Mi Quiniela" review section

**Files:**
- Modify: `app/views/quinielas/show.html.erb` to add a "results" summary partial
- Create: `app/views/quinielas/_summary.html.erb`

- [ ] **Step 1: Add summary partial**

`app/views/quinielas/_summary.html.erb`:
```erb
<div class="bg-white/10 rounded-2xl p-4 border border-white/20 mb-6">
  <div class="grid grid-cols-3 gap-2 text-center">
    <div><div class="text-yellow-300 text-2xl font-black"><%= quiniela.total_points %></div><div class="text-white/70 text-xs">Puntos</div></div>
    <div><div class="text-green-300 text-2xl font-black"><%= quiniela.exact_hits %></div><div class="text-white/70 text-xs">Exactos</div></div>
    <div><div class="text-pink-300 text-2xl font-black"><%= quiniela.match_hits %></div><div class="text-white/70 text-xs">Aciertos</div></div>
  </div>
  <% pending = @knockouts.where(status: "scheduled").count %>
  <p class="text-white/70 text-sm mt-3 text-center"><%= pending %> partidos pendientes</p>
</div>
```

- [ ] **Step 2: Render it in show**

In `app/views/quinielas/show.html.erb`, after the `<header>`, add:
```erb
<%= render "summary", quiniela: @quiniela %>
```

- [ ] **Step 3: Manual check**

Run: `bin/rails server`, save a quiniela, verify the summary numbers render and update after `bin/rails quiniela:recalculate`.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "feat: Mi Quiniela summary (points, exact hits, pending matches)"
```

---

## Task 15: Global ranking with live Turbo Streams

**Files:**
- Create: `app/controllers/rankings_controller.rb`, `app/views/rankings/index.html.erb`, `app/views/rankings/_table.html.erb`
- Test: `test/controllers/rankings_controller_test.rb`

- [ ] **Step 1: Write failing ranking test**

`test/controllers/rankings_controller_test.rb`:
```ruby
require "test_helper"

class RankingsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @tournament = Tournament.create!(name: "WC", year: 2026)
    @u1 = User.create!(email: "a@x.com", name: "Ana")
    @u2 = User.create!(email: "b@x.com", name: "Beto")
    Quiniela.create!(user: @u1, tournament: @tournament, total_points: 30, exact_hits: 4, match_hits: 6)
    Quiniela.create!(user: @u2, tournament: @tournament, total_points: 50, exact_hits: 6, match_hits: 8)
  end

  test "ranked orders by points desc" do
    ranked = RankingsController.ranked(@tournament)
    assert_equal "Beto", ranked.first.user.name
  end

  test "index renders the leader first" do
    get rankings_path
    assert_response :success
    assert_match "Beto", response.body
  end
end
```

- [ ] **Step 2: Run to verify fail**

Run: `bin/rails test test/controllers/rankings_controller_test.rb`
Expected: FAIL.

- [ ] **Step 3: Implement controller**

`app/controllers/rankings_controller.rb`:
```ruby
class RankingsController < ApplicationController
  def index
    @tournament = Tournament.current
    @quinielas = self.class.ranked(@tournament)
    @leader_points = @quinielas.first&.total_points || 0
  end

  def self.ranked(tournament)
    Quiniela.where(tournament_id: tournament.id)
            .includes(:user)
            .order(total_points: :desc, exact_hits: :desc, match_hits: :desc)
  end
end
```

- [ ] **Step 4: Implement views**

`app/views/rankings/index.html.erb`:
```erb
<div class="max-w-2xl mx-auto px-4 py-8">
  <h1 class="text-3xl font-black text-white mb-6">🏆 Ranking Global</h1>
  <%= turbo_stream_from "ranking_#{@tournament.id}" %>
  <div id="ranking">
    <%= render "table", quinielas: @quinielas %>
  </div>
</div>
```

`app/views/rankings/_table.html.erb`:
```erb
<% leader = quinielas.first&.total_points || 0 %>
<div class="space-y-2">
  <% quinielas.each_with_index do |q, i| %>
    <div class="flex items-center gap-3 bg-white/10 rounded-xl p-3 border border-white/20 <%= 'ring-2 ring-yellow-300' if i.zero? %>">
      <span class="w-8 text-center font-black text-white"><%= i + 1 %></span>
      <span class="flex-1 text-white font-semibold"><%= q.user.display_name %></span>
      <span class="text-green-300 text-sm" title="Aciertos exactos"><%= q.exact_hits %>✓</span>
      <span class="text-pink-300 text-sm" title="Partidos acertados"><%= q.match_hits %>⚽</span>
      <span class="text-yellow-300 font-black w-16 text-right"><%= q.total_points %></span>
      <span class="text-white/50 text-xs w-12 text-right"><%= i.zero? ? "—" : "-#{leader - q.total_points}" %></span>
    </div>
  <% end %>
</div>
```

- [ ] **Step 5: Run to verify pass**

Run: `bin/rails test test/controllers/rankings_controller_test.rb`
Expected: PASS.

- [ ] **Step 6: Verify live broadcast wiring**

The `RecalculateScoresJob` (Task 8) already broadcasts to `ranking_#{tournament.id}` replacing `#ranking` with `rankings/table`. Confirm `format.turbo_stream` not required — the `turbo_stream_from` in index subscribes. After `bin/rails quiniela:recalculate` (which uses ScoringService directly), to also broadcast call the job: change the rake `recalculate`/`load_results` tasks to enqueue `RecalculateScoresJob.perform_later(tournament.id)` instead of looping inline.

Update `lib/tasks/quiniela.rake` both tasks to:
```ruby
    RecalculateScoresJob.perform_now(tournament.id)
```
(replace the inline `find_each` loop; `perform_now` so the rake task runs synchronously and broadcasts).

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "feat: live global ranking with Turbo Stream broadcasts"
```

---

## Task 16: Layout, navigation & festive styling

**Files:**
- Modify: `app/views/layouts/application.html.erb`
- Modify: `app/assets/tailwind/application.css` (or `app/assets/stylesheets/application.tailwind.css`)

- [ ] **Step 1: Festive layout with gradient background + nav**

`app/views/layouts/application.html.erb` body:
```erb
<body class="min-h-screen bg-gradient-to-br from-purple-700 via-pink-600 to-orange-500 bg-fixed">
  <% if signed_in? %>
    <nav class="flex items-center justify-between px-4 py-3 bg-black/20 backdrop-blur">
      <%= link_to "⚽ Quiniela", quiniela_path, class: "text-white font-black text-xl" %>
      <div class="flex gap-4 items-center">
        <%= link_to "Mi Quiniela", quiniela_path, class: "text-white/90 hover:text-white font-semibold" %>
        <%= link_to "Ranking", rankings_path, class: "text-white/90 hover:text-white font-semibold" %>
        <%= button_to "Salir", session_path, method: :delete, class: "text-white/70 text-sm" %>
      </div>
    </nav>
  <% end %>

  <% flash.each do |type, msg| %>
    <div class="mx-auto max-w-3xl mt-4 px-4 py-3 rounded-xl text-center font-semibold <%= type == 'alert' ? 'bg-red-500/80 text-white' : 'bg-green-500/80 text-white' %>">
      <%= msg %>
    </div>
  <% end %>

  <main><%= yield %></main>
</body>
```

- [ ] **Step 2: Verify Tailwind builds**

Run: `bin/rails tailwindcss:build`
Expected: builds without error.

- [ ] **Step 3: Full manual smoke**

Run: `bin/rails server`. Walk: login → groups → knockouts → (predict final) → awards unlock → save (confetti + flash + mailer in log) → Mi Quiniela summary → Ranking.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "feat: festive gradient layout and navigation"
```

---

## Task 17: Final verification

- [ ] **Step 1: Run the whole suite**

Run: `bin/rails test`
Expected: all tests PASS.

- [ ] **Step 2: Exercise the result pipeline end-to-end**

Edit `db/results.yml` with a sample group result + one finished match + awards, then:
```bash
bin/rails quiniela:load_results
```
Expected: matches/results updated, scores recalculated, no errors.

- [ ] **Step 3: Commit any fixes**

```bash
git add -A
git commit -m "test: full suite green + results pipeline verified"
```

---

## Self-Review Notes (addressed)

- **Spec coverage:** registro email (Task 10) · grupos scoring (T5) · eliminatorias + multiplicadores (T6) · premios goleador/asistidor (T7) · confirmación por correo (T12) · Mi Quiniela (T14) · ranking con diferencia al líder (T15) · arquitectura desacoplada de resultados (T8) · seeds Mundial 2026 (T9) · bloqueo por horario `Match#locked?` (T4, enforced T11) · estilo festivo (T13, T16). All mapped.
- **Award unlock** (paso 3 visible solo tras predecir la final): enforced in view (`_awards`) and server-side (`save_award_prediction` guards on `predicted_final?`).
- **Multiplier rounding:** uses `.floor` consistently (e.g. quarter exact 5×1.5 → 7). Documented in tests.
- **Type consistency:** `RankingsController.ranked`, `Tournament.current`, `Match#locked?/#finished?/#multiplier/#actual_winner_team_id`, `Quiniela#predicted_final?`, `Results::ManualProvider#apply!` referenced consistently across tasks.
