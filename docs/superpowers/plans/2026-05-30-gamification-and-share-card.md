# Gamification + Share Card Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add achievements (Profeta, Nostradamus, Remontada), celebration polish (confetti levels + leader-change crown), and a client-generated shareable card to the World Cup quiniela app.

**Architecture:** A persisted `Achievement` model + a Ruby catalog of rules evaluated by `AchievementEvaluator` after scoring (in the save flow and the recalc job). Frontend Stimulus controllers handle confetti levels, the leader-change crown, and canvas card generation. Champion/rank helpers live on `Quiniela`.

**Tech Stack:** Rails 8, Hotwire/Stimulus, Minitest, PostgreSQL, Tailwind, Canvas + Web Share API.

---

## File Structure

- `db/migrate/*_create_achievements.rb` — achievements table.
- `db/migrate/*_add_worst_rank_to_quinielas.rb` — worst_rank column.
- `app/models/achievement.rb` — earned-achievement record.
- `app/models/quiniela.rb` — associations + `current_rank`, champion helpers.
- `app/services/achievement_catalog.rb` — rule registry (single source of truth).
- `app/services/achievement_evaluator.rb` — evaluate + persist + return newly earned.
- `app/controllers/predictions_controller.rb` — evaluate on save, surface earned.
- `app/jobs/recalculate_scores_job.rb` — evaluate for everyone after recaldc.
- `app/controllers/rankings_controller.rb` — preload achievements.
- `app/views/quinielas/_achievements.html.erb` — "Mis logros" section.
- `app/views/quinielas/show.html.erb` — render achievements + earned banner + share button.
- `app/views/rankings/_table.html.erb` — `data-user-id` + badge emojis.
- `app/views/rankings/index.html.erb` — leaderboard wrapper.
- `app/javascript/controllers/celebrate_controller.js` — confetti `level`, clean params.
- `app/javascript/controllers/leaderboard_controller.js` — crown on leader change.
- `app/javascript/controllers/share_card_controller.js` — canvas + Web Share.
- Tests under `test/models`, `test/services`, `test/controllers`.

---

## Task 1: Achievement model + worst_rank

**Files:**
- Create: `db/migrate/<ts>_create_achievements.rb`, `db/migrate/<ts2>_add_worst_rank_to_quinielas.rb`
- Create: `app/models/achievement.rb`
- Modify: `app/models/quiniela.rb`
- Test: `test/models/achievement_test.rb`

- [ ] **Step 1: Write the failing test**

Create `test/models/achievement_test.rb`:

```ruby
require "test_helper"

class AchievementTest < ActiveSupport::TestCase
  def setup
    SeedLoader.call
    @tournament = Tournament.current
    @user = User.create!(username: "achiever")
    @quiniela = @user.quinielas.create!(tournament: @tournament)
  end

  test "a quiniela has many achievements" do
    @quiniela.achievements.create!(key: "profeta", earned_at: Time.current)
    assert_equal ["profeta"], @quiniela.reload.achievements.map(&:key)
  end

  test "the same achievement key cannot be earned twice by a quiniela" do
    @quiniela.achievements.create!(key: "profeta", earned_at: Time.current)
    assert_raises(ActiveRecord::RecordNotUnique) do
      @quiniela.achievements.create!(key: "profeta", earned_at: Time.current)
    end
  end
end
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bin/rails test test/models/achievement_test.rb`
Expected: FAIL — `uninitialized constant Achievement` / no `achievements` association.

- [ ] **Step 3: Create the migrations**

`bin/rails generate migration CreateAchievements`, then set its body:

```ruby
class CreateAchievements < ActiveRecord::Migration[8.0]
  def change
    create_table :achievements do |t|
      t.references :quiniela, null: false, foreign_key: true
      t.string :key, null: false
      t.datetime :earned_at, null: false
      t.timestamps
    end
    add_index :achievements, [:quiniela_id, :key], unique: true
  end
end
```

`bin/rails generate migration AddWorstRankToQuinielas`, then:

```ruby
class AddWorstRankToQuinielas < ActiveRecord::Migration[8.0]
  def change
    add_column :quinielas, :worst_rank, :integer
  end
end
```

- [ ] **Step 4: Run the migrations**

Run: `bin/rails db:migrate`
Expected: `achievements` table created with unique index; `quinielas.worst_rank` added; `db/schema.rb` updated.

- [ ] **Step 5: Create the model + associations**

Create `app/models/achievement.rb`:

```ruby
class Achievement < ApplicationRecord
  belongs_to :quiniela
  validates :key, presence: true
end
```

In `app/models/quiniela.rb`, add the association after the existing `has_one :award_prediction` line:

```ruby
  has_many :achievements, dependent: :destroy
```

- [ ] **Step 6: Run it to verify it passes**

Run: `bin/rails test test/models/achievement_test.rb`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add app/models/achievement.rb app/models/quiniela.rb db/migrate db/schema.rb test/models/achievement_test.rb
git commit -m "feat(achievements): Achievement model + worst_rank column"
```

---

## Task 2: Quiniela rank + champion helpers

**Files:**
- Modify: `app/models/quiniela.rb`
- Test: `test/models/quiniela_test.rb`

- [ ] **Step 1: Write the failing test**

Append these tests inside `test/models/quiniela_test.rb` (before the final `end`):

```ruby
  test "current_rank is 1 for the top scorer and increases below" do
    leader = @user.quinielas.first || @quiniela
    leader.update!(total_points: 100)
    other = User.create!(username: "second").quinielas.create!(tournament: @tournament, total_points: 40)
    assert_equal 1, leader.current_rank
    assert_equal 2, other.current_rank
  end

  test "champion_correct? compares predicted final winner to the real one" do
    final = @tournament.matches.find_by(phase: "final")
    teams = Team.limit(2).to_a
    final.update!(home_team: teams[0], away_team: teams[1],
                  home_goals: 2, away_goals: 1, status: "finished")
    @quiniela.match_predictions.create!(match: final, pred_home: 3, pred_away: 0)
    assert @quiniela.champion_correct?           # predicted home wins == real home wins

    @quiniela.match_predictions.find_by(match: final).update!(pred_home: 0, pred_away: 3)
    assert_not @quiniela.reload.champion_correct? # predicted away, home won
  end
```

(The `@quiniela` in this file is created in the existing `setup`.)

- [ ] **Step 2: Run it to verify it fails**

Run: `bin/rails test test/models/quiniela_test.rb`
Expected: FAIL — `undefined method 'current_rank'`.

- [ ] **Step 3: Add the helpers**

In `app/models/quiniela.rb`, add these public methods (after `predicted_final?`):

```ruby
  # Approximate live rank within the tournament (ties ignored — fine for the
  # "+10 places" achievement trigger).
  def current_rank
    tournament.quinielas_relation.where("total_points > ?", total_points).count + 1
  end

  def final_match
    tournament.matches.find_by(phase: "final")
  end

  def predicted_champion
    m = final_match
    return nil unless m
    mp = match_predictions.find_by(match_id: m.id)
    return nil unless mp
    Team.find_by(id: mp.predicted_winner_team_id || mp.penalty_qualifier_id)
  end

  def real_champion
    m = final_match
    return nil unless m&.finished?
    Team.find_by(id: m.actual_winner_team_id || m.penalty_winner_id)
  end

  def champion_correct?
    predicted = predicted_champion
    real = real_champion
    predicted.present? && real.present? && predicted.id == real.id
  end
```

- [ ] **Step 4: Run it to verify it passes**

Run: `bin/rails test test/models/quiniela_test.rb`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add app/models/quiniela.rb test/models/quiniela_test.rb
git commit -m "feat(quiniela): current_rank + predicted/real champion helpers"
```

---

## Task 3: Achievement catalog + evaluator

**Files:**
- Create: `app/services/achievement_catalog.rb`, `app/services/achievement_evaluator.rb`
- Test: `test/services/achievement_evaluator_test.rb`

- [ ] **Step 1: Write the failing test**

Create `test/services/achievement_evaluator_test.rb`:

```ruby
require "test_helper"

class AchievementEvaluatorTest < ActiveSupport::TestCase
  def setup
    SeedLoader.call
    @tournament = Tournament.current
    @user = User.create!(username: "evaltester")
    @quiniela = @user.quinielas.create!(tournament: @tournament)
  end

  test "awards Profeta at 5 exact hits and returns it once" do
    @quiniela.update!(exact_hits: 5)
    newly = AchievementEvaluator.new(@quiniela, current_rank: 1).call
    assert_equal ["profeta"], newly.map(&:key)
    assert @quiniela.achievements.exists?(key: "profeta")

    again = AchievementEvaluator.new(@quiniela, current_rank: 1).call
    assert_empty again # not earned twice
  end

  test "does not award Profeta below 5 exact hits" do
    @quiniela.update!(exact_hits: 4)
    newly = AchievementEvaluator.new(@quiniela, current_rank: 1).call
    assert_not (newly.map(&:key).include?("profeta"))
  end

  test "awards Remontada after climbing 10+ places and tracks worst_rank" do
    AchievementEvaluator.new(@quiniela, current_rank: 15).call
    assert_equal 15, @quiniela.reload.worst_rank
    assert_not @quiniela.achievements.exists?(key: "remontada")

    newly = AchievementEvaluator.new(@quiniela, current_rank: 5).call # climbed 10
    assert_includes newly.map(&:key), "remontada"
  end
end
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bin/rails test test/services/achievement_evaluator_test.rb`
Expected: FAIL — `uninitialized constant AchievementEvaluator`.

- [ ] **Step 3: Create the catalog**

Create `app/services/achievement_catalog.rb`:

```ruby
# Single source of truth for the achievements: their display data and the rule
# that earns each. Rules receive a context exposing `quiniela` and `rank_climb`.
module AchievementCatalog
  Entry = Struct.new(:key, :name, :emoji, :description, :rule, keyword_init: true)

  ALL = [
    Entry.new(key: "profeta", name: "Profeta", emoji: "🔮",
              description: "Acumula 5 marcadores exactos.",
              rule: ->(c) { c.quiniela.exact_hits >= 5 }),
    Entry.new(key: "nostradamus", name: "Nostradamus", emoji: "🏆",
              description: "Acertaste al campeón del Mundial.",
              rule: ->(c) { c.quiniela.champion_correct? }),
    Entry.new(key: "remontada", name: "Remontada", emoji: "🚀",
              description: "Subiste 10+ puestos en el ranking.",
              rule: ->(c) { c.rank_climb >= 10 }),
  ].freeze

  # Big achievements trigger the louder ("epic") celebration.
  EPIC_KEYS = %w[nostradamus].freeze

  def self.find(key)
    ALL.find { |e| e.key == key }
  end
end
```

- [ ] **Step 4: Create the evaluator**

Create `app/services/achievement_evaluator.rb`:

```ruby
# Evaluates the achievement catalog against a quiniela's current state, persists
# any newly earned ones, and returns them (as catalog entries). Also maintains
# worst_rank, used by the Remontada rule.
class AchievementEvaluator
  Context = Struct.new(:quiniela, :rank_climb, keyword_init: true)

  def initialize(quiniela, current_rank:)
    @quiniela = quiniela
    @current_rank = current_rank
  end

  def call
    worst = [@quiniela.worst_rank || @current_rank, @current_rank].max
    @quiniela.update!(worst_rank: worst) if worst != @quiniela.worst_rank

    context = Context.new(quiniela: @quiniela, rank_climb: worst - @current_rank)
    earned = @quiniela.achievements.pluck(:key)

    AchievementCatalog::ALL.each_with_object([]) do |entry, newly|
      next if earned.include?(entry.key)
      next unless entry.rule.call(context)
      @quiniela.achievements.create!(key: entry.key, earned_at: Time.current)
      newly << entry
    end
  end
end
```

- [ ] **Step 5: Run it to verify it passes**

Run: `bin/rails test test/services/achievement_evaluator_test.rb`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add app/services/achievement_catalog.rb app/services/achievement_evaluator.rb test/services/achievement_evaluator_test.rb
git commit -m "feat(achievements): catalog of rules + evaluator"
```

---

## Task 4: Wire evaluator into save + recalc

**Files:**
- Modify: `app/controllers/predictions_controller.rb`
- Modify: `app/jobs/recalculate_scores_job.rb`
- Test: `test/controllers/predictions_controller_test.rb`

- [ ] **Step 1: Write the failing test**

Append inside `test/controllers/predictions_controller_test.rb` (before the final `end`):

```ruby
  test "earning an achievement on save redirects with the logros flag" do
    # Pre-seed 4 exact hits via finished matches isn't needed; force the counter
    # through a complete save then bump exacts to cross the Profeta threshold.
    post quiniela_predictions_path, params: complete_first_part_params
    q = @user.quinielas.find_by(tournament: @tournament)
    q.update!(exact_hits: 5)

    post quiniela_predictions_path, params: complete_first_part_params
    assert q.reload.achievements.exists?(key: "profeta")
    assert_match(/logros=profeta/, @response.headers["Location"].to_s)
  end
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bin/rails test test/controllers/predictions_controller_test.rb`
Expected: FAIL — no achievement created / no `logros` param.

- [ ] **Step 3: Wire the controller**

In `app/controllers/predictions_controller.rb`, replace the success tail (the block starting `ScoringService.new(@quiniela).call`) with:

```ruby
    ScoringService.new(@quiniela).call
    earned = AchievementEvaluator.new(@quiniela, current_rank: @quiniela.current_rank).call

    params_out = {}
    params_out[:fase1] = 1 if just_completed
    params_out[:logros] = earned.map(&:key).join(",") if earned.any?

    if params_out.any?
      redirect_to quiniela_path(params_out)
    else
      redirect_to quiniela_path, notice: "¡Quiniela guardada!"
    end
  end
```

(Keep the earlier `unless saved … return` block unchanged above this.)

- [ ] **Step 4: Wire the job**

Replace `app/jobs/recalculate_scores_job.rb` `perform` body with:

```ruby
  def perform(tournament_id)
    tournament = Tournament.find(tournament_id)
    tournament.quinielas_relation.find_each { |q| ScoringService.new(q).call }
    RankingsController.ranked(tournament).each_with_index do |quiniela, i|
      AchievementEvaluator.new(quiniela, current_rank: i + 1).call
    end
    Turbo::StreamsChannel.broadcast_replace_to(
      "ranking_#{tournament.id}",
      target: "ranking",
      partial: "rankings/table",
      locals: { quinielas: RankingsController.ranked(tournament) }
    )
  end
```

- [ ] **Step 5: Run it to verify it passes**

Run: `bin/rails test test/controllers/predictions_controller_test.rb`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add app/controllers/predictions_controller.rb app/jobs/recalculate_scores_job.rb test/controllers/predictions_controller_test.rb
git commit -m "feat(achievements): evaluate on save and on score recalculation"
```

---

## Task 5: Achievement display (quiniela + ranking)

**Files:**
- Create: `app/views/quinielas/_achievements.html.erb`
- Modify: `app/views/quinielas/show.html.erb`
- Modify: `app/views/rankings/_table.html.erb`, `app/controllers/rankings_controller.rb`
- Test: `test/controllers/quinielas_controller_test.rb`

- [ ] **Step 1: Write the failing test**

Append inside `test/controllers/quinielas_controller_test.rb` (before the final `end`):

```ruby
  test "shows the achievements section with earned and locked badges" do
    q = @user.quinielas.find_or_create_by!(tournament: Tournament.current)
    q.achievements.create!(key: "profeta", earned_at: Time.current)
    get quiniela_path
    assert_match "Mis logros", response.body
    assert_match "Profeta", response.body       # earned
    assert_match "Nostradamus", response.body    # locked but listed
  end
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bin/rails test test/controllers/quinielas_controller_test.rb`
Expected: FAIL — "Mis logros" not present.

- [ ] **Step 3: Create the achievements partial**

Create `app/views/quinielas/_achievements.html.erb`:

```erb
<% earned = quiniela.achievements.index_by(&:key) %>
<div class="surface p-5 mb-6">
  <h3 class="font-display font-extrabold text-xl text-white uppercase tracking-wide mb-4">🏅 Mis logros</h3>
  <div class="grid grid-cols-1 sm:grid-cols-3 gap-3">
    <% AchievementCatalog::ALL.each do |a| %>
      <% got = earned[a.key] %>
      <div class="rounded-xl border p-3 flex items-center gap-3 <%= got ? 'border-gold/60 bg-gold/10' : 'border-white/10 bg-pitch-900/40 opacity-70' %>">
        <span class="text-2xl <%= 'grayscale' unless got %>"><%= a.emoji %></span>
        <div class="min-w-0">
          <div class="font-display font-bold text-white truncate"><%= a.name %></div>
          <div class="text-white/60 text-xs leading-snug"><%= got ? "¡Desbloqueado!" : a.description %></div>
        </div>
      </div>
    <% end %>
  </div>
</div>
```

- [ ] **Step 4: Render it on the quiniela page**

In `app/views/quinielas/show.html.erb`, add after the summary line `<%= render "summary", quiniela: @quiniela %>`:

```erb
  <%= render "achievements", quiniela: @quiniela %>
```

- [ ] **Step 5: Preload + show badges in the ranking**

In `app/controllers/rankings_controller.rb`, change the `ranked` includes to add achievements:

```ruby
  def self.ranked(tournament)
    Quiniela.where(tournament_id: tournament.id)
            .includes(:achievements, user: :favorite_team)
            .order(total_points: :desc, exact_hits: :desc, match_hits: :desc)
  end
```

In `app/views/rankings/_table.html.erb`, add `data-user-id` to the row div and badges next to the name. Change the row opening div to include `data-user-id="<%= q.user_id %>"`, and after the `<span class="truncate"><%= q.user.display_name %></span>` line add:

```erb
            <% q.achievements.each do |a| %><span title="<%= AchievementCatalog.find(a.key)&.name %>"><%= AchievementCatalog.find(a.key)&.emoji %></span><% end %>
```

- [ ] **Step 6: Run it to verify it passes**

Run: `bin/rails test test/controllers/quinielas_controller_test.rb test/controllers/rankings_controller_test.rb`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add app/views/quinielas/_achievements.html.erb app/views/quinielas/show.html.erb app/views/rankings/_table.html.erb app/controllers/rankings_controller.rb test/controllers/quinielas_controller_test.rb
git commit -m "feat(achievements): display on quiniela page and ranking rows"
```

---

## Task 6: Celebration polish (confetti levels + leader crown + earned banner)

**Files:**
- Modify: `app/javascript/controllers/celebrate_controller.js`
- Create: `app/javascript/controllers/leaderboard_controller.js`
- Modify: `app/views/quinielas/show.html.erb` (earned banner)
- Modify: `app/views/rankings/index.html.erb`
- Modify: `app/assets/tailwind/application.css` (crown animation)

No automated JS tests (no headless browser) — verified manually in Step 6.

- [ ] **Step 1: Add confetti levels + clean params to celebrate**

Replace `app/javascript/controllers/celebrate_controller.js` with:

```javascript
import { Controller } from "@hotwired/stimulus"

// Celebration: fires confetti on connect (intensity by `level`) and stays until
// the user closes it. Cleans its trigger params from the URL so a refresh won't
// re-open it.
export default class extends Controller {
  static values = { level: { type: String, default: "normal" } }

  connect() {
    this.burst()
    if (window.history.replaceState) {
      const url = new URL(window.location.href)
      ;["fase1", "logros"].forEach((p) => url.searchParams.delete(p))
      window.history.replaceState({}, "", url)
    }
  }

  close() { this.element.remove() }

  burst() {
    const epic = this.levelValue === "epic"
    const colors = epic
      ? ["#ffc531", "#ffd766", "#f0a800", "#4ade80", "#38bdf8"]
      : ["#ffc531", "#4ade80", "#38bdf8", "#ff5d7d"]
    const count = epic ? 160 : 80
    const fall = epic ? 3.2 : 2.4
    for (let i = 0; i < count; i++) {
      const c = document.createElement("div")
      c.style.cssText = `position:fixed;top:-10px;left:${Math.random() * 100}vw;width:10px;height:10px;background:${colors[i % colors.length]};z-index:10000;border-radius:2px;transition:transform ${fall}s ease-out, opacity ${fall}s;`
      document.body.appendChild(c)
      requestAnimationFrame(() => {
        c.style.transform = `translateY(100vh) rotate(${Math.random() * 720}deg)`
        c.style.opacity = "0"
      })
      setTimeout(() => c.remove(), fall * 1000 + 200)
    }
  }
}
```

- [ ] **Step 2: Earned-achievement banner on the quiniela page**

In `app/views/quinielas/show.html.erb`, add just before the final `</div>` of the page (right after the `<% if params[:fase1] %> … <% end %>` modal block), this banner:

```erb
  <% if params[:logros].present? %>
    <% keys = params[:logros].to_s.split(",") %>
    <% epic = (keys & AchievementCatalog::EPIC_KEYS).any? %>
    <div data-controller="celebrate" data-celebrate-level-value="<%= epic ? 'epic' : 'normal' %>"
         class="fixed inset-x-0 top-4 z-[1100] flex justify-center px-4">
      <div class="surface surface-neon p-4 max-w-md w-full flex items-center gap-3 hero-in">
        <span class="text-3xl"><%= keys.map { |k| AchievementCatalog.find(k)&.emoji }.join %></span>
        <div class="flex-1 min-w-0">
          <div class="font-display font-extrabold text-gold uppercase tracking-wide">¡Logro desbloqueado!</div>
          <div class="text-white/85 text-sm truncate"><%= keys.map { |k| AchievementCatalog.find(k)&.name }.compact.join(" · ") %></div>
        </div>
        <button type="button" data-action="celebrate#close" aria-label="Cerrar"
                class="text-white/55 hover:text-white text-2xl leading-none cursor-pointer">&times;</button>
      </div>
    </div>
  <% end %>
```

- [ ] **Step 3: Leaderboard crown controller**

Create `app/javascript/controllers/leaderboard_controller.js`:

```javascript
import { Controller } from "@hotwired/stimulus"

// Watches the live-updating ranking; when the #1 row's user changes (after a
// Turbo broadcast replaces the table), flies a 👑 onto the new leader's row.
export default class extends Controller {
  connect() {
    this.ranking = this.element.querySelector("#ranking")
    if (!this.ranking) return
    this.leaderId = this.topUserId()
    this.observer = new MutationObserver(() => this.check())
    this.observer.observe(this.ranking, { childList: true, subtree: true })
  }

  disconnect() { this.observer && this.observer.disconnect() }

  topUserId() {
    return this.ranking.querySelector("[data-user-id]")?.dataset.userId || null
  }

  check() {
    const now = this.topUserId()
    if (!now || now === this.leaderId) { this.leaderId = now; return }
    this.leaderId = now
    const row = this.ranking.querySelector(`[data-user-id="${now}"]`)
    if (!row) return
    const crown = document.createElement("div")
    crown.textContent = "👑"
    crown.className = "crown-fly"
    const r = row.getBoundingClientRect()
    crown.style.left = `${r.left + 12}px`
    crown.style.top = `${r.top - 8}px`
    document.body.appendChild(crown)
    setTimeout(() => crown.remove(), 1600)
  }
}
```

- [ ] **Step 4: Wrap the ranking + crown CSS**

In `app/views/rankings/index.html.erb`, wrap the live region with the controller. Replace:

```erb
  <%= turbo_stream_from "ranking_#{@tournament.id}" %>
  <div id="ranking">
    <%= render "table", quinielas: @quinielas %>
  </div>
```

with:

```erb
  <div data-controller="leaderboard">
    <%= turbo_stream_from "ranking_#{@tournament.id}" %>
    <div id="ranking">
      <%= render "table", quinielas: @quinielas %>
    </div>
  </div>
```

In `app/assets/tailwind/application.css`, append at the end:

```css
/* Leader-change crown fly-in. */
@keyframes crownFly {
  0%   { transform: translateY(-40px) scale(0.6) rotate(-20deg); opacity: 0; }
  35%  { transform: translateY(0) scale(1.25) rotate(0deg); opacity: 1; }
  100% { transform: translateY(-4px) scale(1) rotate(0deg); opacity: 0; }
}
.crown-fly {
  position: fixed; z-index: 1200; font-size: 2rem; pointer-events: none;
  animation: crownFly 1.6s ease-out forwards;
}
@media (prefers-reduced-motion: reduce) { .crown-fly { animation: none; opacity: 0; } }
```

- [ ] **Step 5: Build assets**

Run: `bin/rails tailwindcss:build`
Expected: `Done` with no errors.

- [ ] **Step 6: Manual verification**

Run `bin/dev`. (a) Save a quiniela that crosses 5 exacts → earned banner + confetti. (b) Open `/rankings` in two windows; change scores so the leader flips → 👑 flies onto the new top row.

- [ ] **Step 7: Commit**

```bash
git add app/javascript/controllers/celebrate_controller.js app/javascript/controllers/leaderboard_controller.js app/views/quinielas/show.html.erb app/views/rankings/index.html.erb app/assets/tailwind/application.css
git commit -m "feat(celebration): confetti levels, earned banner, leader-change crown"
```

---

## Task 7: Shareable card

**Files:**
- Create: `app/javascript/controllers/share_card_controller.js`
- Modify: `app/views/quinielas/show.html.erb` (share button + data)
- Test: `test/controllers/quinielas_controller_test.rb`

- [ ] **Step 1: Write the failing test**

Append inside `test/controllers/quinielas_controller_test.rb` (before the final `end`):

```ruby
  test "shows the share-card button with player data when submitted" do
    q = @user.quinielas.find_or_create_by!(tournament: Tournament.current)
    q.update!(submitted_at: Time.current, total_points: 42)
    get quiniela_path
    assert_select "[data-controller='share-card']"
    assert_select "[data-share-card-points-value='42']"
  end

  test "no share-card button before submitting" do
    @user.quinielas.find_or_create_by!(tournament: Tournament.current).update!(submitted_at: nil)
    get quiniela_path
    assert_select "[data-controller='share-card']", false
  end
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bin/rails test test/controllers/quinielas_controller_test.rb`
Expected: FAIL — no `share-card` controller element.

- [ ] **Step 3: Create the share-card controller**

Create `app/javascript/controllers/share_card_controller.js`:

```javascript
import { Controller } from "@hotwired/stimulus"

// Draws a summary card on a canvas (no network → no canvas tainting) and shares
// it via the Web Share API (WhatsApp/Stories on mobile); falls back to a PNG
// download on desktop/unsupported browsers.
export default class extends Controller {
  static values = {
    username: String, flag: String, points: Number, exact: Number,
    hits: Number, rank: Number, champion: String, championFlag: String
  }

  async share() {
    const blob = await this.draw()
    const file = new File([blob], "mi-quiniela-mundial.png", { type: "image/png" })
    const text = `Mi quiniela del Mundial: ${this.pointsValue} pts 🏆`
    if (navigator.canShare && navigator.canShare({ files: [file] })) {
      try { await navigator.share({ files: [file], title: "Mi Quiniela Mundial", text }) } catch { /* cancelled */ }
    } else {
      const a = document.createElement("a")
      a.href = URL.createObjectURL(blob)
      a.download = file.name
      a.click()
      URL.revokeObjectURL(a.href)
    }
  }

  draw() {
    const W = 1080, H = 1080
    const cv = document.createElement("canvas")
    cv.width = W; cv.height = H
    const ctx = cv.getContext("2d")
    // Pitch background
    ctx.fillStyle = "#0a3a1e"; ctx.fillRect(0, 0, W, H)
    ctx.strokeStyle = "rgba(234,255,241,0.25)"; ctx.lineWidth = 6
    ctx.strokeRect(40, 40, W - 80, H - 80)
    ctx.textAlign = "center"
    ctx.fillStyle = "#ffc531"; ctx.font = "900 64px 'Barlow Condensed', sans-serif"
    ctx.fillText("MIQUIMUNDI", W / 2, 170)
    ctx.fillStyle = "#eafff1"; ctx.font = "700 44px 'Barlow', sans-serif"
    ctx.fillText(`${this.flagValue} ${this.usernameValue}`, W / 2, 260)
    // Big points
    ctx.fillStyle = "#ffc531"; ctx.font = "900 260px 'Anton', sans-serif"
    ctx.fillText(String(this.pointsValue), W / 2, 580)
    ctx.fillStyle = "#eafff1"; ctx.font = "700 40px 'Barlow Condensed', sans-serif"
    ctx.fillText("PUNTOS", W / 2, 650)
    // Stats row
    ctx.font = "700 40px 'Barlow', sans-serif"
    ctx.fillStyle = "#4ade80"; ctx.fillText(`✓ ${this.exactValue} exactos`, W / 2 - 230, 760)
    ctx.fillStyle = "#ff5d7d"; ctx.fillText(`⚽ ${this.hitsValue} aciertos`, W / 2 + 230, 760)
    ctx.fillStyle = "#38bdf8"; ctx.fillText(`#${this.rankValue} en el ranking`, W / 2, 840)
    if (this.championValue) {
      ctx.fillStyle = "#ffd766"; ctx.font = "700 44px 'Barlow Condensed', sans-serif"
      ctx.fillText(`🏆 Mi campeón: ${this.championFlagValue} ${this.championValue}`, W / 2, 960)
    }
    return new Promise((resolve) => cv.toBlob(resolve, "image/png"))
  }
}
```

- [ ] **Step 4: Add the button + data on the quiniela page**

In `app/views/quinielas/show.html.erb`, inside the existing `<% if @quiniela.submitted? %>` Compartir block, add this button after the closing `</div>` of the copy-link row (still inside the `data-controller="clipboard"` div is fine, or place right after that block). Add a new block right after the Compartir `</div>` (line ~56):

```erb
  <% if @quiniela.submitted? %>
    <% champ = @quiniela.predicted_champion %>
    <div class="mb-6" data-controller="share-card"
         data-share-card-username-value="<%= @quiniela.user.display_name %>"
         data-share-card-flag-value="<%= @quiniela.user.favorite_team&.flag_emoji %>"
         data-share-card-points-value="<%= @quiniela.total_points %>"
         data-share-card-exact-value="<%= @quiniela.exact_hits %>"
         data-share-card-hits-value="<%= @quiniela.match_hits %>"
         data-share-card-rank-value="<%= @quiniela.current_rank %>"
         data-share-card-champion-value="<%= champ&.name %>"
         data-share-card-champion-flag-value="<%= champ&.flag_emoji %>">
      <button type="button" data-action="share-card#share" class="btn-primary w-full">
        📲 Compartir mi tarjeta
      </button>
    </div>
  <% end %>
```

- [ ] **Step 5: Run it to verify it passes**

Run: `bin/rails test test/controllers/quinielas_controller_test.rb`
Expected: PASS.

- [ ] **Step 6: Manual verification**

Run `bin/dev`, open `/quiniela` on a saved quiniela, tap "📲 Compartir mi tarjeta": on mobile the share sheet opens with the PNG; on desktop a PNG downloads. Confirm points/stats/champion render.

- [ ] **Step 7: Commit**

```bash
git add app/javascript/controllers/share_card_controller.js app/views/quinielas/show.html.erb test/controllers/quinielas_controller_test.rb
git commit -m "feat(share): client-generated summary card via canvas + Web Share"
```

---

## Self-Review Notes

- **Spec coverage:** achievements model+catalog+evaluator (T1–T3), wiring on save + recalc (T4), display on quiniela + ranking (T5), confetti levels + earned banner + leader crown (T6), share card (T7). Streaks/"Goleador" intentionally out of scope.
- **Type/name consistency:** `AchievementCatalog::ALL`/`EPIC_KEYS`/`.find`, `AchievementEvaluator#call` returning catalog entries, `Quiniela#current_rank`/`predicted_champion`/`champion_correct?`, `worst_rank`, `data-user-id`, `share-card` value names (`points`, `champion`, `championFlag`) all consistent across tasks.
- **Nothing pushed:** all commits are local; the user reviews the running app before any push.
- **Manual-only pieces:** confetti, crown animation, and canvas/Web Share are verified by hand (no headless browser available).
