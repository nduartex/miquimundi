# Ventana tardía para rezagados (Fase 1 post-kickoff)

**Fecha:** 2026-06-11
**Estado:** Aprobado

## Problema

El Mundial inició el 2026-06-11 18:00 UTC. Desde ese momento `Tournament#locked?` congela toda la Fase 1 (grupos, terceros, premios) y las eliminatorias siguen bloqueadas hasta que termine la fase de grupos (`knockout_open?`). Resultado: un usuario que no alcanzó a llenar su quiniela queda sin nada que hacer durante ~2 semanas, y queda fuera del juego completo.

## Decisiones de producto

| Decisión | Valor |
|---|---|
| ¿Quién puede llenar tarde? | Solo quien NUNCA completó la Fase 1 (`first_part_completed_at IS NULL`). Quien ya guardó queda cerrado. |
| ¿Hasta cuándo? | Hasta el inicio de la jornada 3 de grupos: **2026-06-21 16:00 UTC** (cada equipo con máx. 2 partidos jugados). |
| Penalización | **-25%** sobre los puntos de lo llenado tarde: grupos + terceros + premios. Eliminatorias sin castigo (abren igual para todos). |
| ¿Ediciones posteriores? | No. Un solo guardado (Fase 1 completa, gate existente); al guardar se autobloquea. |

## Diseño técnico

### 1. Datos y modelo

- **Migración:** `add_column :tournaments, :late_deadline_at, :datetime`.
- **Seed:** `db/seeds/world_cup_2026.yml` agrega `late_deadline_at: '2026-06-21T16:00:00Z'`; `SeedLoader` lo asigna junto a `locked_at`.
- **`Tournament#late_window_open?`** → `locked? && late_deadline_at.present? && late_deadline_at.future?`
- **`Quiniela#late?`** → `first_part_completed_at.present? && tournament.locked_at.present? && first_part_completed_at > tournament.locked_at`
- **`Quiniela#first_part_editable?`** → `!tournament.locked? || (tournament.late_window_open? && first_part_completed_at.nil?)`

No se agregan columnas a `quinielas`: `first_part_completed_at` ya existe y se setea una única vez al completar la Fase 1. Nota: `submitted_at` NO sirve como marca de tardío porque se actualiza en cada guardado (incluidos guardados de knockouts post-bloqueo).

### 2. Controller (`predictions_controller.rb`)

Los cuatro chequeos `@tournament.locked?` que gobiernan la Fase 1 (guardar grupos/terceros/premios, gate de completitud, milestone `first_part_completed_at`, limpieza de `best_third_groups`) pasan a usar un único flag local `editable = @quiniela.first_part_editable?` calculado al inicio del request.

Flujo del rezagado: guarda Fase 1 completa en un intento (si está incompleta, rollback con el alert existente) → `first_part_completed_at` se llena → siguiente request `first_part_editable? == false` → autobloqueo. `save_match_predictions` no cambia.

### 3. Scoring (`scoring_service.rb`)

- Constante `LATE_MULTIPLIER = 0.75`.
- En `call`: `phase1 = score_groups + score_thirds + score_awards`; si `@quiniela.late?` → `phase1 = (phase1 * LATE_MULTIPLIER).floor`. `score_matches` queda fuera del descuento.
- Los `points_earned` por registro (group_predictions, award_prediction) quedan en bruto; el descuento se aplica una sola vez al subtotal. La UI que muestre detalle debe aclarar el descuento con el badge (sección 4).

### 4. UI

- **Banner rezagado** (torneo locked + `first_part_editable?`): "El Mundial ya comenzó, pero aún puedes llenar tu quiniela hasta el 21 de junio. Tus puntos de grupos, terceros y premios valdrán 75%. Tienes un solo guardado."
- **Banner cerrado actual** se mantiene para quien ya guardó o cuando pasó el deadline.
- `@groups_locked` (vista `quinielas/show`) pasa de `@tournament.locked?` a `!@quiniela.first_part_editable?` — los partials (`_group_stage`, `_thirds`, `_awards`) y `gate_enforce_value` ya consumen ese flag; solo cambia la fuente.
- **Ranking** (global y de liga): badge "tardía" junto a quinielas con `late?`, para transparencia frente a los demás miembros.

### 5. Tests

- **Tournament:** `late_window_open?` (antes del kickoff, dentro de ventana, después del deadline, sin `late_deadline_at`).
- **Quiniela:** `late?` (completó antes vs. después del kickoff), `first_part_editable?` (4 combinaciones).
- **PredictionsController:** rezagado guarda Fase 1 post-kickoff dentro de ventana ✓; su segundo guardado de Fase 1 es ignorado ✓; usuario que guardó pre-kickoff sigue bloqueado ✓; post-deadline nadie guarda Fase 1 ✓; guardado incompleto hace rollback ✓.
- **ScoringService:** quiniela `late?` recibe `(subtotal_fase1 * 0.75).floor`; quiniela puntual recibe puntos completos; knockouts sin descuento en ambas.

## Casos borde

- Usuario puntual que luego guarda knockouts: `submitted_at` se mueve pero `first_part_completed_at` no → nunca `late?`. ✓
- Rezagado que solo guarda knockouts cuando abran (post-deadline): `first_part_completed_at` queda nil, Fase 1 nunca puntúa, sin descuento sobre knockouts. ✓
- `late_deadline_at` nil (torneos futuros sin ventana): `late_window_open?` false → comportamiento idéntico al actual. ✓

## Fuera de alcance

- Reabrir edición para quienes ya guardaron.
- Penalización en eliminatorias.
- Cambios a creación/unión de ligas (nunca estuvieron bloqueadas).
