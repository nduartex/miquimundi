# Quiniela Mundial 2026 — Diseño

**Fecha:** 2026-05-28
**Estado:** Aprobado para planificación

## Objetivo

Plataforma de quiniela del Mundial 2026 entre amigos: los participantes registran
predicciones, revisan sus resultados y compiten en un ranking global por puntos
acumulados. La arquitectura debe quedar desacoplada para integrar resultados
automáticos (API/scraping) en el futuro sin rehacer la base.

## Stack

- **Ruby 3.2.2 / Rails 8.0.5** — monolito full-stack
- **PostgreSQL**
- **Hotwire** (Turbo + Stimulus) — interactividad y ranking en vivo
- **Tailwind CSS** — estilo visual **vibrante festivo multicolor** (banderas, gradientes,
  confeti al guardar la quiniela, tarjetas tipo álbum)
- **Solid Queue** (jobs nativos Rails 8) — recálculo y envío de correos
- **Action Mailer** — correo de confirmación de quiniela
- **Sin panel de administración** — los resultados se cargan vía rake task + YAML

## Decisiones de diseño

| Tema | Decisión |
|---|---|
| Arquitectura | Monolito Rails + Hotwire/Tailwind |
| Autenticación | Email como identificador único, sin contraseña ni verificación (pool casual entre amigos) |
| Datos del torneo | Seeds del Mundial 2026 (datos reales verificados) |
| Carga de resultados | Rake task + `db/results.yml` (no hay panel admin) |
| Estilo visual | Vibrante festivo multicolor |
| Premios individuales | Goleador y máximo asistidor, elegidos desde lista de jugadores (`Player`) |

## Modelo de datos

```
User             id, email (uniq), name, created_at
Tournament       id, name, year, locked_at
Group            id, tournament_id, name (A..L)
Team             id, group_id, name, code, flag_emoji
Player           id, team_id, name
Quiniela         id, user_id, tournament_id, total_points, exact_hits, match_hits, submitted_at
GroupPrediction  id, quiniela_id, group_id, first_team_id, second_team_id, points_earned
Match            id, tournament_id, phase, home_team_id, away_team_id,
                 home_goals, away_goals, penalty_winner_id, kickoff_at, status, bracket_slot
MatchPrediction  id, quiniela_id, match_id, pred_home, pred_away,
                 penalty_qualifier_id, points_earned
GroupResult      id, group_id, first_team_id, second_team_id
AwardPrediction  id, quiniela_id, top_scorer_player_id, top_assists_player_id, points_earned
TournamentResult id, tournament_id, top_scorer_player_id, top_assists_player_id
```

### Enums

- `Match.phase`: `group, round_16, quarter, semi, final`
- `Match.status`: `scheduled, live, finished`

### Notas del modelo

- Se agregan `Tournament`, `Group`, `Team`, `Player` como tablas con claves foráneas
  (el spec original usaba strings sueltos). Esto hace que el puntaje sea confiable y
  que el seed y la carga de resultados queden limpios.
- La clasificación por penales (`penalty_winner_id`) se evalúa aparte del marcador,
  respetando la regla de que el resultado cuenta durante los 90 minutos reglamentarios.
- `AwardPrediction` referencia jugadores por `player_id` (selección desde lista, no texto libre).

## Motor de puntaje — `ScoringService`

Servicio puro e idempotente, recalculable en cualquier momento. Recalcula
`total_points`, `exact_hits` y `match_hits` por quiniela.

**Fase de grupos**
- +3 por cada equipo clasificado correctamente (sin importar el orden)
- +2 extra si acierta ambos equipos en el orden exacto

**Eliminatorias (por partido)**
- Marcador exacto (90') → 5
- Acierta el ganador con marcador errado → 2
- Acierta el clasificado por penales → 3 (independiente del marcador)

**Multiplicadores por fase**
- Octavos → x1
- Cuartos → x1.5
- Semifinales → x2
- Final → x3

**Premios individuales** (se desbloquean tras predecir la final)
- Goleador del Mundial → 10
- Máximo asistidor del Mundial → 10

## Flujo de usuario / Pantallas

1. **Landing / Login** — ingresa solo email; es el identificador único.
2. **Armar quiniela** — wizard en 3 pasos:
   - Paso 1 (grupos): elige los 2 clasificados de cada grupo, con orden.
   - Paso 2 (eliminatorias): marcador exacto por partido + quién clasifica por penales.
   - Paso 3 (premios): goleador y máximo asistidor — **visible solo si ya predijo la final**.
   - Al guardar: correo de confirmación + toast + confeti.
3. **Mi Quiniela** — todas las predicciones, puntos acumulados, aciertos/errores,
   partidos pendientes, estado vs resultados reales.
4. **Ranking global** — posición, nombre/email, puntaje total, aciertos exactos,
   partidos acertados, diferencia respecto al primer lugar. Se actualiza en vivo
   con Turbo Stream al recalcular.

## Carga de resultados (sin panel admin)

- Archivo `db/results.yml` con resultados reales (marcadores, penales, premios).
- `rails quiniela:load_results` — actualiza `Match` y `TournamentResult`, dispara
  `ScoringService` para todas las quinielas y hace broadcast del ranking.
- `rails quiniela:recalculate` — recálculo manual.
- Detrás: interfaz `ResultsProvider` con `ManualProvider` (hoy, lee el YAML). Mañana
  se enchufan `ApiProvider` / `ScraperProvider` sin tocar el resto.

## Datos iniciales (seeds)

Mundial 2026 — 12 grupos (A–L), 48 equipos, datos verificados (sorteo 5-dic-2025 +
repechajes 26/31-mar-2026):

| Grupo | Equipos |
|---|---|
| A | México, Sudáfrica, Corea del Sur, Chequia |
| B | Canadá, Bosnia, Catar, Suiza |
| C | Brasil, Marruecos, Haití, Escocia |
| D | Estados Unidos, Paraguay, Australia, Turquía |
| E | Alemania, Curazao, Costa de Marfil, Ecuador |
| F | Países Bajos, Japón, Suecia, Túnez |
| G | Bélgica, Egipto, Irán, Nueva Zelanda |
| H | España, Cabo Verde, Arabia Saudita, Uruguay |
| I | Francia, Senegal, Irak, Noruega |
| J | Argentina, Argelia, Austria, Jordania |
| K | Portugal, RD Congo, Uzbekistán, Colombia |
| L | Inglaterra, Croacia, Ghana, Panamá |

- Repechajes: Bosnia / Suecia / Turquía / Chequia (UEFA); RD Congo (Grupo K) e
  Irak (Grupo I) (intercontinental).
- Fixture de fase de grupos + estructura de eliminatorias.
- `Player` con jugadores notables por equipo (extensible vía seed/rake si falta alguno).
- Se mantiene "2 clasificados por grupo" simple (sin lógica de mejores terceros).

## Preparado para el futuro (sin rehacer la base)

- **Resultados automáticos:** adapters intercambiables vía `ResultsProvider`.
- **Bloqueo por horario:** `Match#locked?` (kickoff pasado) + `tournament.locked_at`;
  rechaza predicciones tardías.
- **Google login:** autenticación aislada en `SessionsController`; se agrega OmniAuth
  sin tocar los modelos.
- **Tiempo real:** ya cubierto con Turbo Streams.

## Tests (TDD)

- Modelos: validaciones y asociaciones.
- `ScoringService`: todos los casos de puntaje, multiplicadores por fase y premios.
- Requests: login, guardar quiniela (incluido desbloqueo del paso de premios),
  visualización de Mi Quiniela y ranking.

## Fuentes

- [FIFA — Final Draw results](https://www.fifa.com/en/tournaments/mens/worldcup/canadamexicousa2026/articles/final-draw-results)
- [Wikipedia — 2026 FIFA World Cup draw](https://en.wikipedia.org/wiki/2026_FIFA_World_Cup_draw)
- [Wikipedia — Inter-confederation play-offs](https://en.wikipedia.org/wiki/2026_FIFA_World_Cup_qualification_(inter-confederation_play-offs))
