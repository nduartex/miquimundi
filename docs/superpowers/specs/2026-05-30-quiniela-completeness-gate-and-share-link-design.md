# Quiniela: completeness gate + public share link

Date: 2026-05-30

Two independent features on top of the existing single-form quiniela:

1. **Completeness gate** — the "first part" (Grupos + Terceros + Premios) can only be
   saved when all three phases are fully marked. Enforced both client- and server-side.
2. **Public share link** — once a quiniela is saved, the owner gets a unique URL that
   shows their predictions (no points) read-only to anyone, without login.

## Context

- `PredictionsController#create` is the single save endpoint. It saves the first part
  (groups, best thirds, awards) only when `tournament.locked?` is false, plus knockout
  predictions (their own guard), then sets `submitted_at` and runs `ScoringService`.
- Groups use drag-and-drop: the four position hidden fields are **always** pre-populated
  from the ordered list, so a group prediction is effectively always complete. The real
  "incomplete" cases are best thirds (0–8 of 8) and awards (0–5 of 5). The gate still
  validates all three phases for robustness.
- `Quiniela.submitted?` already exists (`submitted_at.present?`).
- `User` uses `has_secure_token :access_token` for the private login link — this must
  NOT be exposed publicly; the share feature needs its own token.
- View helpers `thirds_payload(tournament)` and `players_dataset(tournament)` already
  build the JSON datasets the `_thirds` / `_awards` partials need.

## Feature 1 — Completeness gate

### Definition of "complete" (the 3 phases)

- **Grupos:** one `group_prediction` per `tournament.groups`, each with all four of
  `first/second/third/fourth_team_id` present.
- **Terceros:** `best_third_groups` has exactly 8 entries.
- **Premios:** `award_prediction` exists and all five fields are present
  (`balon_oro_player_id`, `bota_oro_player_id`, `guante_oro_player_id`,
  `young_player_id`, `fair_play_team_id`).

### Model — `Quiniela`

Add methods that compute completeness from persisted state (single source of truth):

- `first_part_complete?` → `groups_complete? && best_thirds_complete? && awards_complete?`
- `first_part_missing` → array of human-readable Spanish labels of what's missing
  (e.g. `["Faltan 3 mejores terceros (5/8)", "Falta: Bota de Oro, Fair Play"]`),
  used for the server alert message.

Private predicates:
- `groups_complete?`: `group_predictions.count == tournament.groups.count` and every
  `group_prediction.ranked_team_ids.size == 4`.
- `best_thirds_complete?`: `best_third_groups.size == 8`.
- `awards_complete?`: `award_prediction.present?` and none of the five fields nil.

### Server — `PredictionsController#create`

Only enforce when the first part is still editable, i.e. `!@tournament.locked?`.

```
saved_ok = true
ActiveRecord::Base.transaction do
  unless @tournament.locked?
    save_group_predictions
    save_best_thirds
    save_award_prediction
  end
  save_match_predictions

  if !@tournament.locked? && !@quiniela.reload.first_part_complete?
    saved_ok = false
    raise ActiveRecord::Rollback
  end

  @quiniela.update!(submitted_at: Time.current)
end

if saved_ok
  ScoringService.new(@quiniela).call
  # existing success responses (notice "¡Quiniela guardada!")
else
  redirect with alert: "Completa las 3 fases antes de guardar: " + missing list
end
```

- `reload` is needed so the completeness check sees the just-saved associated records.
- The rollback discards the partial save **and** the `submitted_at` update, so an
  incomplete first part never becomes "submitted" and scoring never runs.
- The alert is built from `@quiniela.first_part_missing` (recomputed before responding,
  or captured before rollback — capture the list before raising so it survives).
- Knockout-only saves (after the Mundial starts, `locked?` true) skip the gate entirely.

`respond_to` must handle both html and turbo_stream for the failure path, mirroring the
success path.

### Client — new Stimulus controller `gate`

Attached to the quiniela `<form>`. Enabled only when not locked
(`data-gate-enforce-value`, set from `!@groups_locked` in the view).

- Targets: the existing submit button (`data-gate-target="submit"`) and a message
  element (`data-gate-target="status"`).
- On `connect` and on `input`/`change` bubbling from the form, recompute:
  - thirds: count checked `input[name="best_third_groups[]"]` → need 8.
  - awards: every `award_prediction[...]` hidden/select has a non-empty value → need 5.
  - groups: every group's four hidden position fields non-empty (defensive; normally
    always true).
- If incomplete: disable submit, show `status` text listing what's missing
  (e.g. "Faltan 3 terceros y 2 premios"). If complete: enable submit, clear status.
- When `enforce` is false, the controller is a no-op (button always enabled) so knockout
  saves and the locked state are unaffected.

The existing `wizard` controller keeps managing visibility/step state; `gate` only owns
the disabled/enabled state of the submit button. They share the same button element via
separate data-target attributes — no conflict (`wizard` toggles step nav, `gate` toggles
`disabled`).

## Feature 2 — Public share link

### Token — `Quiniela`

- Migration: add `share_token:string`, add a unique index, backfill existing rows with
  generated tokens.
- Model: `has_secure_token :share_token` (auto-generated on create; `show` already does
  `@quiniela.save!` for new records so new quinielas get a token immediately).

### Route

```
get "q/:token", to: "shared_quinielas#show", as: :shared_quiniela
```

Public — no `require_login`.

### Controller — `SharedQuinielasController#show`

- Skips the login filter.
- `@quiniela = Quiniela.find_by!(share_token: params[:token])`.
- `@tournament = @quiniela.tournament` and the same collections `show` builds
  (`@groups`, `@knockouts`, `@players`, `@teams`) so the locked partials render.
- Renders `shared_quinielas/show.html.erb`.

### View — `shared_quinielas/show.html.erb`

Read-only page, no form, no submit, no access link, **no points**:

- Header: "Quiniela de @&lt;username&gt;" + favorite-team flag if present.
- Reuses the existing partials in locked/closed mode (they already render disabled
  inputs showing the stored values):
  - `_group_stage` with `locked: true`
  - `_thirds` with `locked: true`
  - `_awards` with `locked: true`
  - `_knockouts` with `open: false` (rendered only if the quiniela has any
    `match_predictions`, so an empty knockout phase isn't shown pre-bracket).
- A small "Esta es una quiniela compartida (solo lectura)" banner.

### Owner's page — `quinielas/show.html.erb`

Add a "Compartir" block (same visual pattern as the existing access-link block, with a
`clipboard` controller and Copiar button) showing `shared_quiniela_url(token:
@quiniela.share_token)`. Visible only when `@quiniela.submitted?`.

## Error handling

- Unknown share token → `find_by!` raises `RecordNotFound` → standard 404.
- Incomplete first part on save → rollback + alert, no state change (covered above).

## Testing

- **Model** (`Quiniela`): `first_part_complete?` true only when all three phases full;
  false for each missing phase; `first_part_missing` lists the right labels.
- **PredictionsController**: incomplete first part is rejected (no `submitted_at`, no
  scoring, alert shown); complete first part saves; when `tournament.locked?`, a
  knockout-only save is NOT blocked by the gate.
- **SharedQuinielasController**: valid token renders predictions and does NOT show
  points or the access link; unknown token → 404; works without a logged-in session.
- **Token**: a new quiniela gets a `share_token`; backfill migration covers existing rows.

## Out of scope

- Showing points on the shared page (explicitly excluded — predictions only).
- Editing or re-sharing controls on the shared page.
- Regenerating/revoking share tokens.
