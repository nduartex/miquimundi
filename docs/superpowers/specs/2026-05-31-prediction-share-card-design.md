# Tarjeta de predicción para compartir — diseño

Fecha: 2026-05-31

## Resumen

Reemplazar la tarjeta de stats actual (puntos / exactos / aciertos / ranking) por
**tarjetas de predicción** que el usuario comparte en stories de Instagram / WhatsApp.
La tarjeta dice "Mi predicción para el Mundial 2026" y muestra lo que el usuario eligió,
no su rendimiento.

Hay **dos tarjetas**, habilitadas por fase del torneo:

1. **Fase 1 — "Mi predicción"** (fase de grupos): equipos que pasan de cada grupo,
   los 8 mejores terceros, y los 5 premios.
2. **Fase 2 — "Mis eliminatorias"**: el bracket de knockouts + el campeón. Se habilita
   cuando arrancan los knockouts.

Ambas se generan en el cliente con `<canvas>` (sin red → sin tainting), tamaño
**1080×1920 (9:16)**, y se comparten con la Web Share API en celular o se previsualizan
y descargan en desktop.

## Contexto del modelo (ya existe)

- `Quiniela has_many :group_predictions` — cada `GroupPrediction` tiene `first_team`,
  `second_team`, `third_team`, `fourth_team` (1°–4° del grupo).
- `Quiniela#best_third_groups` (jsonb) — array de **nombres de grupo** (`["A","C",...]`),
  los 8 grupos cuyo 3° clasifica. El equipo tercero = `group_prediction.third_team` de
  ese grupo.
- `Quiniela has_one :award_prediction` — `balon_oro_player`, `bota_oro_player`,
  `guante_oro_player`, `young_player` (todos `Player`) y `fair_play_team` (`Team`).
- `Player belongs_to :team`; `Team#flag_emoji` da la bandera del país.
- `Quiniela#first_part_complete?` — true cuando grupos + 8 terceros + 5 premios están
  completos. `Quiniela#first_part_missing` da labels de lo que falta.
- `Tournament#knockout_open?` — true cuando los 12 `GroupResult` reales están cargados
  (terminó la fase de grupos). Es el gate de fase 2.
- `Quiniela#predicted_champion`, `#predicted_final?` — para la tarjeta de fase 2.

## Tarjeta Fase 1 — "Mi predicción"

### Habilitación

- El botón "Compartir mi predicción" aparece cuando `first_part_complete?` es true.
- Si no está completa, el botón se muestra deshabilitado con un hint de qué falta
  (reutilizar `first_part_missing`, ej: "Completá: ordenar los grupos, los 5 premios").

### Layout (Opción A — grupos en 2 columnas)

Canvas 1080×1920, fondo verde (gradiente `#0d5129 → #0a3a1e → #062414`) con glow dorado
suave detrás del título, marco redondeado inset, borde `rgba(234,255,241,.22)`.

De arriba a abajo, centrado:

1. **Header**
   - `MI PREDICCIÓN` (Barlow Condensed 900, dorado `#ffc531`)
   - `🇨🇷 Nelson` (nombre del usuario + su bandera de equipo favorito, blanco)
   - `MUNDIAL 2026` (subtítulo chico, espaciado, blanco translúcido)
2. **Pasan de grupos** (label dorado)
   - Grilla de **2 columnas × 6 filas** (12 grupos). Cada celda:
     `A  1.🇲🇽 México · 2.🇨🇦 Canadá`
   - Letra de grupo en dorado; nombres completos en blanco; el `1.`/`2.` en dorado.
   - **Nombres completos, sin abreviaturas.** La fuente de cada celda se auto-ajusta
     (medir con `measureText`, reducir tamaño hasta que entre en el ancho de columna)
     para que entren nombres largos como "Países Bajos" / "Estados Unidos".
3. **Mejores terceros** (label dorado)
   - 8 países en grilla 2 columnas: `🇨🇦 Canadá`. Derivados de `best_third_groups`
     → `third_team` de cada grupo.
4. **Premios** (label dorado)
   - 5 líneas, label a la izquierda (translúcido) y valor a la derecha (blanco, negrita):
     - `Balón de Oro` → `Lionel Messi 🇦🇷`
     - `Bota de Oro` → `Kylian Mbappé 🇫🇷`
     - `Guante de Oro` → `Thibaut Courtois 🇧🇪`
     - `Mejor joven` → `Lamine Yamal 🇪🇸`
     - `Fair Play` → `Japón 🇯🇵` (equipo)
   - Para los 4 premios de jugador, la bandera es `player.team.flag_emoji`. Para Fair Play,
     `team.flag_emoji`.
5. **Footer**: `miquimundi` (chico, translúcido).

### Banderas

Se usan **emojis de bandera**. Se renderizan como banderas reales en iOS/Android (donde
el usuario comparte). En Windows el navegador no tiene glifos de bandera y el preview en
desktop mostrará los códigos de 2 letras ("MX") — es aceptable porque la imagen que se
comparte se genera y se ve en el celular. (Alternativa futura: banderas como imágenes vía
`Team#flag_url`, fuera de alcance.)

## Tarjeta Fase 2 — "Mis eliminatorias"

### Habilitación

- El botón "Compartir mis eliminatorias" aparece cuando `tournament.knockout_open?` es true
  **y** el usuario cargó sus llaves (`predicted_final?`).

### Layout

Mismo estilo visual (verde, 1080×1920). De arriba a abajo:

1. Header `MIS ELIMINATORIAS` + nombre del usuario + `MUNDIAL 2026`.
2. Bracket por ronda, una sección por fase en orden (`Match::PHASE_ORDER` /
   `matches.knockout.ordered`): 32avos → 16avos → 8vos → 4tos → Semis → Final, mostrando
   los equipos que el usuario predijo que avanzan en cada cruce (nombre + bandera).
3. **Mi campeón**: `predicted_champion` destacado en dorado al final.
4. Footer `miquimundi`.

El detalle fino del bracket (cuántos cruces mostrar por ronda sin saturar) se ajusta en
implementación; las rondas tempranas con 16/32 equipos pueden resumirse listando los
clasificados de la ronda en grilla en vez de cada cruce. Esta tarjeta es la entrega de la
"fase 2" y puede implementarse aunque el gate todavía no esté abierto (queda oculta hasta
que `knockout_open?`).

## Flujo de datos / arquitectura

- La vista `quinielas/show` (sección que hoy tiene `data-controller="share-card"`) embebe
  un **JSON** vía `<script type="application/json">` con la forma:

  ```json
  {
    "title": "MI PREDICCIÓN",
    "username": "Nelson",
    "userFlag": "🇨🇷",
    "groups": [
      { "name": "A", "first": { "name": "México", "flag": "🇲🇽" },
        "second": { "name": "Canadá", "flag": "🇨🇦" } }
    ],
    "thirds": [ { "name": "Canadá", "flag": "🇨🇦" } ],
    "awards": [ { "label": "Balón de Oro", "name": "Lionel Messi", "flag": "🇦🇷" } ]
  }
  ```

  Un helper de Rails arma este hash desde `group_predictions`, `best_third_groups`,
  `award_prediction`. La tarjeta de fase 2 embebe su propio JSON análogo (rondas + campeón).

- El controller Stimulus `share-card` (existente) se reescribe para:
  - Leer el JSON embebido (en vez de los `*-value` de stats).
  - Dibujar el canvas 1080×1920 con el layout de fase 1 (y fase 2 cuando aplique).
  - `await document.fonts.ready` antes de dibujar.
  - Compartir: Web Share API con el `File` PNG en móvil; en desktop revelar preview inline
    (`<img>`) + link de descarga, sin popup. (Esta parte ya está hecha y se conserva.)

## Lo que se elimina / cambia

- Se quitan los `data-share-card-*-value` de stats (`points`, `exact`, `hits`, `rank`,
  `champion`) y el dibujo basado en stats del controller.
- Se conserva: la lógica de `share()` (Web Share + preview + descarga), el helper
  `roundRect`, `await fonts.ready`, y el bloque de preview/descarga en la vista.
- `config.hosts`, `bin/dev`, `Procfile.dev` y los cambios del card 9:16 ya hechos en esta
  sesión quedan como están.

## Fuera de alcance

- Banderas como imágenes (assets PNG/SVG) para que se vean en Windows.
- Personalización de colores/tema por usuario.
- Compartir a una red social específica vía API (se usa el share nativo del SO).

## Criterios de aceptación

- Con la primera parte completa, "Compartir mi predicción" genera un PNG 1080×1920 que
  muestra los 12 grupos (2 col, nombres completos), 8 mejores terceros y 5 premios con la
  bandera del país de cada jugador, y todo entra sin cortarse.
- Con la primera parte incompleta, el botón está deshabilitado e indica qué falta.
- En móvil abre el share nativo (IG/WS stories); en desktop muestra preview + descarga.
- Cuando `knockout_open?` y el usuario predijo el final, aparece "Compartir mis
  eliminatorias" con el bracket + campeón.
