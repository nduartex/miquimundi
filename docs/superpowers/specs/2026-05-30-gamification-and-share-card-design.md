# Gamification (achievements + celebration polish) + shareable card

Date: 2026-05-30

Three related but independent subsystems that add "World Cup flow" to the quiniela
app. Built in order 1 → 2 → 3. Streaks ("días seguidos acertando") are explicitly
deferred to a later iteration (will be added as another achievement type).

## Context

- `ScoringService#call` recomputes `total_points`, `exact_hits`, `match_hits` for one
  quiniela. Called from `PredictionsController#create` (after save) and from
  `RecalculateScoresJob` (loops every quiniela when results are loaded, then broadcasts
  the rankings table via Turbo).
- Ranking order: `total_points DESC, exact_hits DESC, match_hits DESC`
  (`RankingsController.ranked`). The live ranking is a `broadcast_replace` of
  `rankings/_table` into `#ranking`.
- Champion (real): winner of the `final` match — `final.actual_winner_team_id` (or
  `final.penalty_winner_id` if it went to penalties). Predicted champion: the final
  match prediction's `predicted_winner_team_id` (or `penalty_qualifier_id`).
- Existing Stimulus: `confetti#burst` (DOM confetti), `celebrate` (milestone modal).
- `Team#flag_emoji` and `Team#flag_url` exist; `User#favorite_team`, `User#display_name`.

---

## Subsystem 1 — Achievements engine

### Definition of achievements (v1)

| key | Name | Emoji | Rule |
|---|---|---|---|
| `profeta` | Profeta | 🔮 | `quiniela.exact_hits >= 5` |
| `nostradamus` | Nostradamus | 🏆 | predicted champion == real champion (eval once the final is finished) |
| `remontada` | Remontada | 🚀 | `worst_rank - current_rank >= 10` |

### Data model

- New table `achievements`: `quiniela_id` (FK, not null), `key` (string, not null),
  `earned_at` (datetime, not null). Unique index `(quiniela_id, key)` so each is earned
  once. `Achievement belongs_to :quiniela`; `Quiniela has_many :achievements`.
- `quinielas`: add `worst_rank` (integer, nullable) — the worst (highest-number) rank
  the quiniela has held, used for Remontada.

### Catalog

`AchievementCatalog` — an ordered registry (array of frozen structs/hashes), one entry
per achievement: `key`, `name`, `emoji`, `description`, and `rule` (a lambda taking a
small context object). Single source of truth for both evaluation and display.

```ruby
Entry = Struct.new(:key, :name, :emoji, :description, :rule, keyword_init: true)
ALL = [
  Entry.new(key: "profeta", name: "Profeta", emoji: "🔮",
            description: "Acumula 5 marcadores exactos.",
            rule: ->(c) { c.quiniela.exact_hits >= 5 }),
  Entry.new(key: "nostradamus", name: "Nostradamus", emoji: "🏆",
            description: "Acertaste al campeón del Mundial.",
            rule: ->(c) { c.champion_correct? }),
  Entry.new(key: "remontada", name: "Remontada", emoji: "🚀",
            description: "Subiste 10+ puestos en el ranking.",
            rule: ->(c) { c.rank_climb >= 10 }),
]
```

### Rank + champion context

- `Quiniela#current_rank` — `tournament.quinielas_relation.where("total_points > ?",
  total_points).count + 1` (cheap, tiebreakers ignored — fine for the +10 trigger).
- Champion helpers on the quiniela (or in the evaluator context):
  - real champion id = `final.actual_winner_team_id || final.penalty_winner_id` where
    `final = tournament.matches.find_by(phase: "final")` and `final&.finished?`.
  - predicted champion id = final's `match_prediction.predicted_winner_team_id ||
    penalty_qualifier_id`.
  - `champion_correct?` = both present and equal.

### Evaluator

`AchievementEvaluator.new(quiniela, current_rank:)` :
1. Update `worst_rank = [worst_rank || current_rank, current_rank].max`; compute
   `rank_climb = worst_rank - current_rank` (used by the remontada rule). Persist
   `worst_rank`.
2. For each catalog entry not already earned by this quiniela, evaluate `rule`; if true,
   create the `Achievement` (with `earned_at: Time.current`).
3. Return the array of newly-earned catalog entries.

Called after `ScoringService#call` in:
- `PredictionsController#create` — `current_rank` via `quiniela.current_rank`; newly
  earned entries are surfaced to the view (see Subsystem 2 trigger).
- `RecalculateScoresJob` — after scoring all quinielas, compute each rank from the
  already-ordered set and evaluate; broadcast as today (badges appear on next render).

### Display

- Quiniela page (`show`): a "🏅 Mis logros" section — earned ones in colour (emoji +
  name + earned), not-yet-earned greyed with their description as a hint. Read from
  `@quiniela.achievements` + the catalog.
- Ranking rows (`rankings/_table`): small earned-emoji badges next to the name.

### Testing

- `AchievementCatalog`/rules: each rule fires under the right condition.
- `AchievementEvaluator`: creates missing, never duplicates (unique index), returns only
  newly earned, updates `worst_rank`, awards remontada at ≥10 climb.
- `PredictionsController`: earning Profeta on save exposes it to the view.

---

## Subsystem 2 — Celebration polish

### Confetti levels

`celebrate` controller gains a `level` value (`normal` | `epic`). `normal` = current
burst; `epic` = ~2× count, longer fall, gold-weighted palette. When a save earns
achievements, the celebration shows the achievement name(s) and uses `epic` if any earned
achievement is "big" (nostradamus) else `normal`. The existing first-part modal stays
`normal`.

### Leader-change crown

`leaderboard` Stimulus controller on a wrapper **outside** `#ranking` (survives the
Turbo broadcast replace). A `MutationObserver` on `#ranking` fires when the table is
replaced; it reads the top row's `data-user-id`, compares to the previously stored id,
and if it changed (and not first load) animates a 👑 flying onto the new leader card.
Add `data-user-id` to each ranking row and an `id`/anchor on the leader card.

### Testing

Frontend only — verified manually (no headless browser). Controllers kept small and
self-contained; rankings partial gains `data-user-id` (assertable in a controller test).

---

## Subsystem 3 — Shareable card

### Generation (client-side canvas)

`share-card` Stimulus controller draws a card onto a hidden `<canvas>` from `data-*`
attributes (no network → no canvas tainting): app title, `username`, favourite-team
**emoji** (`flag_emoji`), big `total_points`, `exact_hits`/`match_hits`, rank `#N`, and
predicted champion (team name + emoji, or "—" if the final isn't set yet). Themed:
pitch-green background, gold accents, poster font drawn as text.

### Share / fallback

`canvas.toBlob` → `File` → `navigator.share({ files: [file], title, text })` when
`navigator.canShare?.({files})` (mobile WhatsApp/Stories). Desktop/unsupported fallback:
trigger a PNG download of the same blob.

### Trigger + data

A "📲 Compartir mi tarjeta" button next to the existing "Compartir" block on the quiniela
page, shown when `@quiniela.submitted?`. Data passed via `data-share-card-*`:
`username`, `flag` (emoji), `points`, `exact`, `hits`, `rank` (`@quiniela.current_rank`),
`champion` (predicted champion name or ""), `championFlag` (emoji or "").

### Testing

Canvas/share is verified manually. The controller test asserts the button + correct
`data-*` values render when submitted, and that it's absent otherwise.

---

## Delivery & out of scope

- One spec, one plan, implemented 1 → 2 → 3. Nothing pushed until the user reviews it
  running locally.
- **Out of scope (deferred):** streaks (daily/consecutive), "Goleador de puntos" tier
  achievement, server-side image rendering, full-bracket image, achievement push
  notifications when earned off-session (badges simply appear on next visit).
