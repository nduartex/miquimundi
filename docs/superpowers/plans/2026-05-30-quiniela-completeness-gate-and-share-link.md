# Quiniela Completeness Gate + Public Share Link Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Block saving the first part of the quiniela (Grupos + Terceros + Premios) until all three phases are complete, and give each saved quiniela a unique public read-only share link (predictions only, no points).

**Architecture:** Completeness is computed from persisted state by `Quiniela#first_part_complete?` (single source of truth). The server gate wraps the save in a transaction and rolls back if incomplete; a Stimulus `gate` controller mirrors the check client-side to disable the button. Sharing adds a `share_token` to `Quiniela` (separate from the user's private `access_token`) and a public `SharedQuinielasController` that renders the existing partials in locked/read-only mode.

**Tech Stack:** Rails 8 (edge), Hotwire/Stimulus, Minitest integration + model tests, PostgreSQL, Tailwind.

---

## File Structure

- `app/models/award_prediction.rb` — add `FIELDS` constant + `complete?` (one place defining the 5 award fields).
- `app/models/quiniela.rb` — add `first_part_complete?` / `first_part_missing` and private phase predicates; add `has_secure_token :share_token`.
- `app/controllers/predictions_controller.rb` — wrap save in a gate; reuse `AwardPrediction::FIELDS`.
- `app/javascript/controllers/gate_controller.js` — new Stimulus controller, client-side button gate.
- `app/controllers/shared_quinielas_controller.rb` — new public controller.
- `app/views/shared_quinielas/show.html.erb` — new read-only page reusing existing partials.
- `app/views/quinielas/show.html.erb` — wire `gate` into the form; add "Compartir" block.
- `config/routes.rb` — add `GET /q/:token`.
- `db/migrate/<ts>_add_share_token_to_quinielas.rb` — new migration + backfill.
- Tests: `test/models/quiniela_test.rb`, `test/controllers/predictions_controller_test.rb`, `test/controllers/shared_quinielas_controller_test.rb` (new).

---

## Task 1: Award completeness helper

**Files:**
- Modify: `app/models/award_prediction.rb`
- Test: `test/models/quiniela_test.rb` (covered indirectly in Task 2; this task adds the constant + method)

- [ ] **Step 1: Add the FIELDS constant and `complete?` to AwardPrediction**

Edit `app/models/award_prediction.rb` to add, after the `belongs_to` lines:

```ruby
  FIELDS = %i[balon_oro_player_id bota_oro_player_id guante_oro_player_id
              young_player_id fair_play_team_id].freeze

  def complete?
    FIELDS.all? { |f| public_send(f).present? }
  end
```

- [ ] **Step 2: Point the controller at the shared constant (DRY)**

In `app/controllers/predictions_controller.rb`, delete the local `AWARD_FIELDS` constant (lines 65-66) and change `save_award_prediction` to use `AwardPrediction::FIELDS`:

```ruby
  def save_award_prediction
    attrs = params[:award_prediction]
    return if attrs.blank?
    award = @quiniela.award_prediction || @quiniela.build_award_prediction
    award.update!(AwardPrediction::FIELDS.index_with { |f| attrs[f].presence })
  end
```

- [ ] **Step 3: Run the existing model + controller suites to confirm no regression yet**

Run: `bin/rails test test/models/quiniela_test.rb test/controllers/predictions_controller_test.rb`
Expected: PASS (no behavior change yet; the controller tests still exercise partial saves — they break in Task 3, not here).

- [ ] **Step 4: Commit**

```bash
git add app/models/award_prediction.rb app/controllers/predictions_controller.rb
git commit -m "refactor: AwardPrediction::FIELDS + complete? (single award-field source)"
```

---

## Task 2: Quiniela completeness + share_token

**Files:**
- Modify: `app/models/quiniela.rb`
- Create: `db/migrate/<timestamp>_add_share_token_to_quinielas.rb`
- Test: `test/models/quiniela_test.rb`

- [ ] **Step 1: Write the failing model tests**

Replace the contents of `test/models/quiniela_test.rb` with:

```ruby
require "test_helper"

class QuinielaTest < ActiveSupport::TestCase
  def setup
    SeedLoader.call
    @tournament = Tournament.current
    @user = User.create!(username: "modeltester")
    @quiniela = @user.quinielas.create!(tournament: @tournament)
  end

  # Fill all three phases so the quiniela is a complete "first part".
  def complete!
    @tournament.groups.each do |g|
      t = g.teams.to_a
      @quiniela.group_predictions.create!(
        group: g, first_team: t[0], second_team: t[1], third_team: t[2], fourth_team: t[3]
      )
    end
    @quiniela.update!(best_third_groups: %w[A B C D E F G H])
    player = Player.first
    team = Team.first
    @quiniela.create_award_prediction!(
      balon_oro_player: player, bota_oro_player: player, guante_oro_player: player,
      young_player: player, fair_play_team: team
    )
    @quiniela.reload
  end

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

  test "a quiniela gets a share_token on create" do
    assert @quiniela.share_token.present?
  end

  test "first_part_complete? is true when all three phases are filled" do
    complete!
    assert @quiniela.first_part_complete?
    assert_empty @quiniela.first_part_missing
  end

  test "incomplete groups make first_part incomplete" do
    complete!
    @quiniela.group_predictions.first.destroy
    assert_not @quiniela.reload.first_part_complete?
  end

  test "fewer than 8 thirds make first_part incomplete" do
    complete!
    @quiniela.update!(best_third_groups: %w[A B C])
    assert_not @quiniela.first_part_complete?
    assert(@quiniela.first_part_missing.any? { |m| m.include?("terceros") })
  end

  test "missing an award makes first_part incomplete" do
    complete!
    @quiniela.award_prediction.update!(fair_play_team_id: nil)
    assert_not @quiniela.reload.first_part_complete?
    assert(@quiniela.first_part_missing.any? { |m| m.include?("premios") })
  end
end
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `bin/rails test test/models/quiniela_test.rb`
Expected: FAIL — `NoMethodError: undefined method 'first_part_complete?'` and `share_token` is nil (no column / no token).

- [ ] **Step 3: Create the migration**

Create `db/migrate/<timestamp>_add_share_token_to_quinielas.rb` (generate the timestamp with `bin/rails generate migration AddShareTokenToQuinielas` then replace the body, or hand-name it later than `20260529041110`):

```ruby
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
```

- [ ] **Step 4: Run the migration**

Run: `bin/rails db:migrate`
Expected: `add_column(:quinielas, :share_token, :string)` and the unique index applied; `db/schema.rb` now shows `share_token` with a unique index.

- [ ] **Step 5: Add the model code**

Edit `app/models/quiniela.rb` to add `has_secure_token :share_token` after the associations, and add the completeness methods. Full file:

```ruby
class Quiniela < ApplicationRecord
  belongs_to :user
  belongs_to :tournament
  has_many :group_predictions, dependent: :destroy
  has_many :match_predictions, dependent: :destroy
  has_one :award_prediction, dependent: :destroy

  has_secure_token :share_token

  def submitted?
    submitted_at.present?
  end

  def predicted_final?
    match_predictions
      .joins(:match)
      .where(matches: { phase: "final" })
      .where.not(pred_home: nil)
      .where.not(pred_away: nil)
      .exists?
  end

  # The "first part" (Grupos + Terceros + Premios) is complete only when all
  # three phases are fully marked. Knockouts open later and are not part of this.
  def first_part_complete?
    groups_complete? && best_thirds_complete? && awards_complete?
  end

  # Spanish labels describing what is still missing, for the save alert.
  def first_part_missing
    missing = []
    missing << "ordenar los grupos" unless groups_complete?
    unless best_thirds_complete?
      missing << "los 8 mejores terceros (#{Array(best_third_groups).size}/8)"
    end
    missing << "los 5 premios" unless awards_complete?
    missing
  end

  private

  def groups_complete?
    expected = tournament.groups.count
    return false if expected.zero?
    return false unless group_predictions.size == expected
    group_predictions.all? { |gp| gp.ranked_team_ids.size == 4 }
  end

  def best_thirds_complete?
    Array(best_third_groups).size == 8
  end

  def awards_complete?
    award_prediction&.complete? || false
  end
end
```

- [ ] **Step 6: Run the tests to verify they pass**

Run: `bin/rails test test/models/quiniela_test.rb`
Expected: PASS (all tests green).

- [ ] **Step 7: Commit**

```bash
git add app/models/quiniela.rb db/migrate db/schema.rb test/models/quiniela_test.rb
git commit -m "feat(quiniela): first_part_complete? gate + public share_token"
```

---

## Task 3: Server-side save gate

**Files:**
- Modify: `app/controllers/predictions_controller.rb:4-25`
- Test: `test/controllers/predictions_controller_test.rb`

- [ ] **Step 1: Rewrite the controller test for the new gated behavior**

Replace the contents of `test/controllers/predictions_controller_test.rb` with:

```ruby
require "test_helper"

class PredictionsControllerTest < ActionDispatch::IntegrationTest
  def setup
    SeedLoader.call
    @tournament = Tournament.current
    @group = @tournament.groups.find_by(name: "A")
    @teams = @group.teams.to_a
    @user = User.create!(username: "tester")
    get restore_path(token: @user.access_token) # log in via personal link
  end

  # Full first part for the seeded tournament. `thirds` overridable to test capping.
  def complete_first_part_params(thirds: %w[A B C D E F G H])
    player = Player.first
    team = Team.first
    {
      group_predictions: @tournament.groups.order(:name).each_with_object({}) do |g, h|
        t = g.teams.to_a
        h[g.id.to_s] = {
          first_team_id: t[0].id, second_team_id: t[1].id,
          third_team_id: t[2].id, fourth_team_id: t[3].id
        }
      end,
      best_third_groups: thirds,
      award_prediction: {
        balon_oro_player_id: player.id, bota_oro_player_id: player.id,
        guante_oro_player_id: player.id, young_player_id: player.id,
        fair_play_team_id: team.id
      }
    }
  end

  test "a complete first part saves records and submits" do
    post quiniela_predictions_path, params: complete_first_part_params
    quiniela = @user.quinielas.find_by(tournament: @tournament)
    assert_not_nil quiniela
    assert quiniela.submitted?
    gp = quiniela.group_predictions.find_by(group: @group)
    assert_equal @teams[0].id, gp.first_team_id
  end

  test "a complete first part stores the full 1-4 group ranking" do
    post quiniela_predictions_path, params: complete_first_part_params
    gp = @user.quinielas.find_by(tournament: @tournament).group_predictions.find_by(group: @group)
    assert_equal [@teams[0].id, @teams[1].id, @teams[2].id, @teams[3].id], gp.ranked_team_ids
  end

  test "best-third group picks are capped at 8" do
    post quiniela_predictions_path, params: complete_first_part_params(thirds: %w[A B C D E F G H I])
    q = @user.quinielas.find_by(tournament: @tournament)
    assert_equal 8, q.best_third_groups.size
    assert_equal %w[A B C D E F G H], q.best_third_groups
  end

  test "an incomplete first part is rejected: nothing saved, not submitted, alert shown" do
    post quiniela_predictions_path, params: {
      group_predictions: { @group.id.to_s => { first_team_id: @teams[0].id, second_team_id: @teams[1].id } }
    }
    q = @user.quinielas.find_by(tournament: @tournament)
    assert_not_nil q                       # quiniela shell exists (created on entry)
    assert_not q.submitted?                # gate rolled back submitted_at
    assert_equal 0, q.group_predictions.count # partial save rolled back too
    assert_match(/Completa las 3 fases/, flash[:alert])
  end

  test "group predictions are frozen and not overwritten once the tournament starts" do
    post quiniela_predictions_path, params: complete_first_part_params
    gp = @user.quinielas.find_by(tournament: @tournament).group_predictions.find_by(group: @group)
    assert_equal @teams[0].id, gp.first_team_id

    @tournament.update!(locked_at: 1.day.ago) # World Cup has started
    post quiniela_predictions_path, params: {
      group_predictions: { @group.id.to_s => { first_team_id: @teams[2].id, second_team_id: @teams[3].id } }
    }
    assert_equal @teams[0].id, gp.reload.first_team_id # original kept, not overwritten
  end

  test "after kickoff the gate does not block a knockout-only save" do
    @tournament.update!(locked_at: 1.day.ago) # World Cup started: first part frozen
    post quiniela_predictions_path, params: {} # nothing to save, but must not be gate-blocked
    assert @user.quinielas.find_by(tournament: @tournament).submitted?
  end

  test "knockout score predictions are ignored while the stage is locked" do
    m = @tournament.matches.find_by(phase: "round_32")
    post quiniela_predictions_path, params: {
      match_predictions: { m.id.to_s => { pred_home: 2, pred_away: 0 } }
    }
    q = @user.quinielas.find_by(tournament: @tournament)
    assert_nil q.match_predictions.find_by(match_id: m.id) # locked: not saved
  end
end
```

- [ ] **Step 2: Run the tests to verify the new ones fail**

Run: `bin/rails test test/controllers/predictions_controller_test.rb`
Expected: FAIL — the "incomplete first part is rejected" test fails (partial save currently persists and submits; no alert).

- [ ] **Step 3: Implement the gate in the controller**

Replace `create` (lines 4-25) in `app/controllers/predictions_controller.rb` with:

```ruby
  def create
    @tournament = Tournament.current
    @quiniela = current_user.quiniela_for(@tournament)
    @quiniela.save! if @quiniela.new_record?

    missing = nil
    saved = false
    ActiveRecord::Base.transaction do
      unless @tournament.locked? # group-stage predictions freeze when the World Cup starts
        save_group_predictions
        save_best_thirds
        save_award_prediction
      end
      save_match_predictions # has its own knockout-open + per-match kickoff guards

      # First part can only be saved when all three phases are complete. The
      # check is skipped once the tournament is locked (first part already frozen;
      # saves then only carry knockout predictions).
      if !@tournament.locked? && !@quiniela.reload.first_part_complete?
        missing = @quiniela.first_part_missing
        raise ActiveRecord::Rollback
      end

      @quiniela.update!(submitted_at: Time.current)
      saved = true
    end

    unless saved
      msg = "Completa las 3 fases antes de guardar: falta #{missing.join(", ")}."
      respond_to do |format|
        format.html { redirect_to quiniela_path, alert: msg }
        format.turbo_stream { flash.now[:alert] = msg }
      end
      return
    end

    ScoringService.new(@quiniela).call

    respond_to do |format|
      format.html { redirect_to quiniela_path, notice: "¡Quiniela guardada!" }
      format.turbo_stream { flash.now[:notice] = "¡Quiniela guardada!" }
    end
  end
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `bin/rails test test/controllers/predictions_controller_test.rb`
Expected: PASS (all 7 tests green).

- [ ] **Step 5: Commit**

```bash
git add app/controllers/predictions_controller.rb test/controllers/predictions_controller_test.rb
git commit -m "feat(predictions): gate first-part save on all three phases being complete"
```

---

## Task 4: Client-side gate (Stimulus)

**Files:**
- Create: `app/javascript/controllers/gate_controller.js`
- Modify: `app/views/quinielas/show.html.erb` (form + submit button + status line)

No automated JS test (the project has no JS test harness); verified manually in Step 4.

- [ ] **Step 1: Create the Stimulus controller**

Create `app/javascript/controllers/gate_controller.js`:

```javascript
import { Controller } from "@hotwired/stimulus"

// Disables the "Guardar" button until the first part (Grupos + Terceros + Premios)
// is fully marked, and shows what's missing. The server is the source of truth;
// this is UX sugar. No-op when enforce is false (e.g. after kickoff the group
// stage is locked and saves only carry knockout predictions).
export default class extends Controller {
  static targets = ["submit", "status"]
  static values = { enforce: Boolean }

  connect() {
    this.refresh = this.refresh.bind(this)
    this.refresh()
  }

  refresh() {
    if (!this.enforceValue) return
    const missing = this.missing()
    const ok = missing.length === 0
    if (this.hasSubmitTarget) {
      this.submitTarget.disabled = !ok
      this.submitTarget.classList.toggle("opacity-40", !ok)
      this.submitTarget.classList.toggle("cursor-not-allowed", !ok)
    }
    if (this.hasStatusTarget) {
      this.statusTarget.textContent = ok ? "" : `Falta: ${missing.join(" · ")}`
      this.statusTarget.hidden = ok
    }
  }

  missing() {
    const out = []

    const thirds = this.element.querySelectorAll(
      'input[name="best_third_groups[]"]:checked'
    ).length
    if (thirds !== 8) out.push(`${Math.max(8 - thirds, 0)} terceros`)

    const awardFields = [
      "balon_oro_player_id", "bota_oro_player_id", "guante_oro_player_id",
      "young_player_id", "fair_play_team_id",
    ]
    const awardsLeft = awardFields.filter((f) => {
      const el = this.element.querySelector(`[name="award_prediction[${f}]"]`)
      return !el || !el.value
    }).length
    if (awardsLeft > 0) out.push(`${awardsLeft} premios`)

    const groupsIncomplete = Array.from(
      this.element.querySelectorAll('[name$="[first_team_id]"]')
    ).some((first) => !first.value)
    if (groupsIncomplete) out.push("ordenar grupos")

    return out
  }
}
```

- [ ] **Step 2: Wire the controller into the form**

In `app/views/quinielas/show.html.erb`, change the `form_with` opening tag (line 61) from:

```erb
  <%= form_with url: quiniela_predictions_path, method: :post, data: { action: "submit->confetti#burst" } do %>
```

to:

```erb
  <%= form_with url: quiniela_predictions_path, method: :post, data: {
        controller: "gate",
        gate_enforce_value: !@groups_locked,
        action: "submit->confetti#burst input->gate#refresh change->gate#refresh"
      } do %>
```

Then change the submit button (lines 84-86) from:

```erb
      <%= submit_tag "🏆 Guardar mi Quiniela",
            data: { wizard_target: "submit" },
            class: "btn-gold flex-1 text-lg" %>
```

to:

```erb
      <%= submit_tag "🏆 Guardar mi Quiniela",
            data: { wizard_target: "submit", gate_target: "submit" },
            class: "btn-gold flex-1 text-lg" %>
```

Finally, add a status line just above the action row. Insert immediately before `<div class="mt-8 flex items-center justify-between gap-3">` (line 75):

```erb
    <p data-gate-target="status" hidden role="status"
       class="mt-6 text-center text-amber-200/90 text-sm font-semibold"></p>
```

- [ ] **Step 3: Build assets so the new controller is registered**

Run: `bin/rails assets:precompile` (or rely on importmap auto-discovery in dev — `app/javascript/controllers/index.js` uses `eagerLoadControllersFrom` if present).
Expected: no errors. If `app/javascript/controllers/index.js` registers controllers explicitly, add `gate_controller`; if it uses `eagerLoadControllersFrom("controllers", application)`, no edit is needed.

- [ ] **Step 4: Manual verification**

Run: `bin/rails server`, log in, open `/quiniela`.
Expected: with terceros/premios unfilled, the "Guardar" button is dimmed/disabled and the status line reads e.g. "Falta: 8 terceros · 5 premios"; after picking 8 thirds and all 5 awards the button enables and the status clears. (Groups are pre-ordered, so they don't block.)

- [ ] **Step 5: Commit**

```bash
git add app/javascript/controllers/gate_controller.js app/views/quinielas/show.html.erb
git commit -m "feat(quiniela): client-side gate disables Guardar until phases complete"
```

---

## Task 5: Public share link

**Files:**
- Modify: `config/routes.rb`
- Create: `app/controllers/shared_quinielas_controller.rb`
- Create: `app/views/shared_quinielas/show.html.erb`
- Modify: `app/views/quinielas/show.html.erb` (add Compartir block)
- Test: `test/controllers/shared_quinielas_controller_test.rb` (new)

- [ ] **Step 1: Write the failing controller test**

Create `test/controllers/shared_quinielas_controller_test.rb`:

```ruby
require "test_helper"

class SharedQuinielasControllerTest < ActionDispatch::IntegrationTest
  def setup
    SeedLoader.call
    @tournament = Tournament.current
    @owner = User.create!(username: "sharer")
    @quiniela = @owner.quinielas.create!(tournament: @tournament, submitted_at: Time.current)
    g = @tournament.groups.order(:name).first
    t = g.teams.to_a
    @quiniela.group_predictions.create!(
      group: g, first_team: t[0], second_team: t[1], third_team: t[2], fourth_team: t[3]
    )
  end

  test "renders the shared quiniela read-only without a login" do
    get shared_quiniela_path(token: @quiniela.share_token)
    assert_response :success
    assert_includes @response.body, "sharer" # owner name shown
  end

  test "does not expose the owner's access token or a save form" do
    get shared_quiniela_path(token: @quiniela.share_token)
    assert_not_includes @response.body, @owner.access_token
    assert_select "input[type=submit]", false
  end

  test "an unknown token is not found" do
    assert_raises(ActiveRecord::RecordNotFound) do
      get shared_quiniela_path(token: "does-not-exist")
    end
  end
end
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bin/rails test test/controllers/shared_quinielas_controller_test.rb`
Expected: FAIL — `NameError`/no route `shared_quiniela_path`.

- [ ] **Step 3: Add the route**

In `config/routes.rb`, add after the `resources :rankings` line (inside the `draw` block):

```ruby
  get "q/:token", to: "shared_quinielas#show", as: :shared_quiniela
```

- [ ] **Step 4: Create the controller**

Create `app/controllers/shared_quinielas_controller.rb` (no `require_login` — `require_login` is opt-in per controller, so this one is public):

```ruby
class SharedQuinielasController < ApplicationController
  def show
    @quiniela = Quiniela.find_by!(share_token: params[:token])
    @owner = @quiniela.user
    @tournament = @quiniela.tournament
    @groups = @tournament.groups.includes(:teams).order(:name)
    @knockouts = @tournament.matches.knockout.ordered
    @players = Player.includes(:team).order("teams.name")
    @teams = Team.joins(:group).where(groups: { tournament_id: @tournament.id }).order(:name)
  end
end
```

- [ ] **Step 5: Create the read-only view**

Create `app/views/shared_quinielas/show.html.erb`. It reuses the existing partials in locked mode (no form, no submit, no access link, no points):

```erb
<% tp = thirds_payload(@tournament) %>
<div class="max-w-3xl mx-auto px-4 py-8">
  <header class="mb-6">
    <div class="flex items-center gap-3 mb-1">
      <% if @owner.favorite_team&.flag_url %>
        <img src="<%= @owner.favorite_team.flag_url %>" alt="" width="34" height="26"
             class="w-[34px] h-[26px] rounded-sm object-cover ring-1 ring-white/15 shrink-0">
      <% end %>
      <h1 class="text-3xl font-extrabold text-white">Quiniela de <%= @owner.display_name %></h1>
    </div>
    <p class="text-white/50 text-sm">Vista compartida · solo lectura</p>
  </header>

  <div class="surface p-6 mb-6">
    <h2 class="font-display text-xl font-bold text-white mb-4">① Grupos</h2>
    <%= render "quinielas/group_stage", groups: @groups, quiniela: @quiniela, locked: true %>
  </div>

  <div class="surface p-6 mb-6">
    <h2 class="font-display text-xl font-bold text-white mb-4">② Mejores terceros</h2>
    <%= render "quinielas/thirds", groups: @groups, quiniela: @quiniela, locked: true,
          teams_json: tp[:teams].to_json, groups_json: tp[:groups].to_json %>
  </div>

  <div class="mb-6">
    <%= render "quinielas/awards", players: @players, teams: @teams, quiniela: @quiniela, locked: true %>
  </div>

  <% if @quiniela.match_predictions.exists? %>
    <div class="surface p-6 mb-6">
      <h2 class="font-display text-xl font-bold text-white mb-4">④ Eliminatorias</h2>
      <%= render "quinielas/knockouts", matches: @knockouts, quiniela: @quiniela, open: false %>
    </div>
  <% end %>
</div>
```

- [ ] **Step 6: Run the test to verify it passes**

Run: `bin/rails test test/controllers/shared_quinielas_controller_test.rb`
Expected: PASS. (If a partial references a helper/local not provided here, the failure message names it — pass the missing local exactly as `quinielas/show.html.erb` does.)

- [ ] **Step 7: Add the "Compartir" block to the owner's page**

In `app/views/quinielas/show.html.erb`, immediately after the access-link block (after line 41, the closing `</div>` of `#access-link`), insert:

```erb
  <% if @quiniela.submitted? %>
    <div class="surface p-4 mb-6" data-controller="clipboard">
      <div class="flex items-center gap-2 mb-2">
        <span class="text-white font-bold">🔗 Comparte tu quiniela</span>
        <span class="text-white/50 text-xs">enlace público de solo lectura (sin puntaje)</span>
      </div>
      <div class="flex gap-2">
        <input type="text" readonly value="<%= shared_quiniela_url(token: @quiniela.share_token) %>"
               data-clipboard-target="source" onclick="this.select()"
               class="field text-sm">
        <button type="button" data-action="clipboard#copy" data-clipboard-target="btn"
                class="px-4 rounded-xl bg-sky-400 text-slate-900 font-bold shrink-0 cursor-pointer">Copiar</button>
      </div>
    </div>
  <% end %>
```

- [ ] **Step 8: Run the full suite**

Run: `bin/rails test`
Expected: PASS (all model + controller tests green).

- [ ] **Step 9: Commit**

```bash
git add config/routes.rb app/controllers/shared_quinielas_controller.rb \
        app/views/shared_quinielas/show.html.erb app/views/quinielas/show.html.erb \
        test/controllers/shared_quinielas_controller_test.rb
git commit -m "feat(share): public read-only quiniela link (predictions only)"
```

---

## Self-Review Notes

- **Spec coverage:** 3-phase definition (Task 2 model), server gate w/ rollback + alert (Task 3), client gate (Task 4), `share_token` separate from `access_token` (Task 2), public route/controller/view predictions-only no-points (Task 5), Compartir block gated on `submitted?` (Task 5). Existing partial-save controller tests rewritten for gated behavior (Task 3). All covered.
- **Knockouts on shared page:** included read-only only when predictions exist (sensible default chosen during brainstorming).
- **Type/name consistency:** `AwardPrediction::FIELDS` used in both model `complete?` and controller; `first_part_complete?` / `first_part_missing` used in controller + tests; `share_token` column + `has_secure_token` + `shared_quiniela_url`/`shared_quiniela_path` consistent across route, views, tests.
- **turbo_stream paths** mirror the existing success pattern exactly (no new template introduced); integration tests exercise the HTML redirect path.
