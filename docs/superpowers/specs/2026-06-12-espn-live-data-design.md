# Integración de datos en vivo de ESPN (Mundial 2026)

**Fecha:** 2026-06-12 · **Estado:** aprobado por Nelson · **Alcance:** solo local, sin deploy a producción.

## Objetivo

Alimentar la app con datos reales del Mundial desde la API pública (no oficial) de ESPN:
resultados/marcadores, goles por partido, tabla de posiciones por grupo y goleadores del
torneo. Nuevas vistas públicas (`/goleadores`, `/posiciones`), resultados en `/calendario`,
y modal "grupo en vivo" dentro de la quiniela.

## Fuente de datos (verificada en vivo el 2026-06-12)

| Dato | Endpoint |
|---|---|
| Partidos del día (marcador, estado) | `https://site.api.espn.com/apis/site/v2/sports/soccer/fifa.world/scoreboard?dates=YYYYMMDD-YYYYMMDD` |
| Goles de un partido (`keyEvents`) | `https://site.api.espn.com/apis/site/v2/sports/soccer/fifa.world/summary?event={espn_id}` |
| Tabla por grupos (con `rank` oficial) | `https://site.api.espn.com/apis/v2/sports/soccer/fifa.world/standings?season=2026` |

Sin API key. Riesgo: API no oficial — el sync nunca borra datos, solo upserta; si ESPN
falla, se loguea y se reintenta al siguiente ciclo.

## Hallazgo clave del repo

Los 72 partidos de fase de grupos **no existen en la BD** (solo los 32 slots de
eliminatorias). El calendario lee `config/fixtures_2026.json` estático. El rake de mapeo
debe **crear** los matches de grupos desde el scoreboard de ESPN.

## Reglas de puntos (decisión de Nelson)

Un FT individual de fase de grupos **no recalcula puntos** (nadie predice marcadores de
grupos). El recálculo (`RecalculateScoresJob`) se dispara solo cuando:

1. Un grupo completa sus 6 partidos → se crea `GroupResult` (1º y 2º por `rank` de ESPN).
2. Los 12 grupos completan → se calculan los 8 mejores terceros (puntos, DG, GF) y se
   guarda `tournament_results.qualified_third_codes`.
3. Un partido de eliminatoria (con `match_prediction`) pasa a FT.

Premios individuales siguen siendo carga manual (results.yml), como hasta ahora.

## Cambios de BD

- `matches.espn_id` (string, índice único) y `teams.espn_id` (string, índice único).
- Nueva tabla `group_standings`: `group_id`, `team_id`, `played`, `wins`, `draws`,
  `losses`, `goals_for`, `goals_against`, `goal_difference`, `points`, `rank`;
  único `[group_id, team_id]`.
- Nueva tabla `goals`: `match_id`, `team_id`, `player_id` (nullable → vínculo a roster
  por nombre normalizado), `player_name`, `minute` (string, ej. `90'+8'`), `own_goal`,
  `penalty`, `sort_order`.

## Servicios (`app/services/espn/`)

- **`Espn::Client`** — Net::HTTP (stdlib, sin gems nuevas), timeouts cortos,
  `Espn::Client::Error` en fallos. Métodos: `scoreboard(dates:)`, `summary(event_id)`,
  `standings`.
- **`Espn::SyncService`** — orquestador idempotente:
  - Upserta matches de grupos (equipo por `abbreviation` ESPN → `teams.code`, con
    diccionario de excepciones), guarda `espn_id` de equipo y partido.
  - Actualiza `status` (`pre→scheduled`, `in→live`, `post→finished`), `home_goals`,
    `away_goals` (también en vivo, para el calendario; el scoring solo cuenta
    `finished`), `penalty_winner_id` en eliminatorias con shootout.
  - Para partidos en vivo o recién FT: fetch `summary` → upserta `goals` desde
    `keyEvents` (autor, minuto, autogol, penal).
  - Tabla: upserta `group_standings` desde el endpoint de standings (rank de ESPN, no
    calculamos desempates nosotros).
  - Eliminatorias: si un evento ESPN no está mapeado, intenta mapear contra un match
    KO de la BD cuyos equipos coincidan (cuando ya estén asignados).
  - Dispara recálculo solo según las reglas de arriba.

## Job recurrente

`EspnSyncJob` cada 1 minuto vía Solid Queue (`config/recurring.yml`, solo `development`
por ahora). Guard barato contra la BD:

- Hay partido con `kickoff_at` entre `now-3h` y `now+10min` → sync completo (scoreboard
  del día + summaries de vivos + standings si hubo FT).
- Si no → solo corre el ciclo completo cuando `min % 15 == 0` (mantiene fixture/standings
  frescos sin spamear a ESPN).

Rakes manuales: `espn:map` (mapeo inicial: crea los 72 matches de grupos + espn_ids de
equipos) y `espn:sync` (una corrida del sync para probar).

## Vistas

1. **`/goleadores`** (pública) — goles agrupados por jugador (excluye autogoles), bandera
   y equipo, orden desc. Derivado de la tabla `goals` (cero requests extra).
2. **`/posiciones`** (pública) — 12 grupos: Pos, equipo, PJ, G, E, P, GF, GC, DG, Pts;
   1º-2º resaltados (clasifican), 3º en dorado (candidato).
3. **`/calendario`** — el JSON estático sigue siendo el esqueleto (fechas/sedes); cada
   entrada se enriquece con el match de BD (grupos: por `kickoff_utc` + iso2 local;
   eliminatorias: por `match_number`): marcador, estado (En vivo/FT) y goles con minuto
   y autor.
4. **Modal grupo en vivo** — en `_group_stage.html.erb`, con la quiniela cerrada
   (`locked`), la insignia "Grupo X" abre un `<dialog>` con un Turbo Frame lazy
   (`GET /grupos/:id/live`): tabla real del grupo + ✓/✗ comparando con la predicción
   del usuario (clasificados que van como predijo).

## Pruebas

Minitest con fixtures JSON reales recortadas de ESPN en `test/fixtures/files/espn/`:

- `Espn::SyncService`: crea/actualiza matches, parsea goles, upserta standings, crea
  `GroupResult` solo con grupo completo, dispara `RecalculateScoresJob` solo en los
  eventos correctos.
- Controllers: goleadores, posiciones, modal de grupo, calendario enriquecido.

Verificación local: `espn:map` + `espn:sync` contra la API real (ya hay 3 partidos
jugados), revisar vistas en `bin/dev`.

## Fuera de alcance

Deploy a producción, asistencias (endpoint core leaders — posible fase 2), asignación
automática de equipos al bracket KO, recálculo de premios automático.
