# Ligas entre amigos — Diseño

**Fecha:** 2026-06-04
**Estado:** Aprobado para implementación

## Resumen

Permitir que los usuarios creen "Ligas" privadas entre amigos: un ranking acotado
a un grupo de personas, usando **exactamente el mismo puntaje del ranking global**
(`quiniela.total_points`). No se introduce ningún sistema de puntaje nuevo: una Liga
es una membresía + un ranking filtrado.

Nota de nombre: el modelo existente `Tournament` representa **el Mundial**. Para no
chocar conceptualmente, la nueva entidad se llama `Liga` (modelo, rutas y UI).

## Decisiones (refinadas con el usuario)

- **Membresía:** un usuario puede estar en varias ligas, sin límite global. La única
  restricción es no estar dos veces en la misma liga (membresía única por liga).
- **Invitación:** por **código de invitación** corto y único que el creador comparte.
- **Creador:** es jugador permanente; **no puede abandonar** la liga.
- **Salida:** cualquier miembro **excepto el creador** puede abandonar voluntariamente.
- **Expulsar:** solo el creador puede quitar a otros miembros (no a sí mismo).
- **Borrar:** solo el creador, y **solo cuando es el único miembro** (todos los demás
  salieron o fueron expulsados). Con otros miembros presentes, el borrado se bloquea.
- **Cupo:** configurable por el creador al crear la liga, entre **2 y 50** (incluye al
  creador).
- **Unirse en cualquier momento:** se permite unirse incluso con el Mundial empezado;
  solo compara puntos ya existentes.

## Modelo de datos

### `Liga`
| Campo | Tipo | Notas |
|---|---|---|
| `name` | string | requerido, 3–40 chars |
| `invite_code` | string | único, 6 chars de alfabeto sin ambigüedad (sin 0/O/1/I/L) |
| `max_players` | integer | 2..50, requerido |
| `creator_id` | bigint → users | creador permanente |
| `tournament_id` | bigint → tournaments | acota el puntaje al Mundial actual |
| timestamps | | |

Índice único en `invite_code`.

Asociaciones:
- `belongs_to :creator, class_name: "User"`
- `belongs_to :tournament`
- `has_many :memberships, class_name: "LigaMembership", dependent: :destroy`
- `has_many :members, through: :memberships, source: :user`

### `LigaMembership`
| Campo | Tipo | Notas |
|---|---|---|
| `liga_id` | bigint → ligas | |
| `user_id` | bigint → users | |
| timestamps | | |

Índice único `[liga_id, user_id]`.

Asociaciones: `belongs_to :liga`, `belongs_to :user`.

`User`: `has_many :liga_memberships, dependent: :destroy`, `has_many :ligas, through: :liga_memberships`.

## Reglas / comportamiento

- **Crear** (`create`): cualquiera logueado. Se asigna `creator`, `tournament =
  Tournament.current`, se genera `invite_code` único, y se crea la membresía del
  creador en la misma transacción.
- **Unirse** (`join`, POST con código): normaliza el código (mayúsculas, trim).
  - Código inexistente → "Código inválido".
  - Ya es miembro → "Ya estás en esta liga".
  - Liga llena (`memberships.count >= max_players`) → "La liga está completa".
  - OK → crea membresía, redirige al `show`.
- **Salir** (`leave`, DELETE): borra la membresía propia.
  - Si es el creador → bloqueado: "El creador no puede abandonar su liga".
- **Expulsar** (`expel`, DELETE membresía de otro): solo el creador; no puede
  expulsarse a sí mismo.
- **Borrar** (`destroy`): solo el creador y solo si `memberships.count == 1`
  (queda únicamente él). Si hay otros → "Solo puedes borrar la liga cuando no quede
  nadie más".

## Puntaje / ranking

Se extrae la consulta de orden actual de `RankingsController.ranked` a un scope
reusable en `Quiniela`, por ejemplo:

```ruby
scope :ranked, ->(tournament, user_ids: nil) {
  rel = where(tournament_id: tournament.id)
        .includes(:achievements, user: :favorite_team)
        .order(total_points: :desc, exact_hits: :desc, match_hits: :desc)
  user_ids ? rel.where(user_id: user_ids) : rel
}
```

`RankingsController#index` pasa a usar `Quiniela.ranked(@tournament)` (mismo resultado,
refactor sin cambio de comportamiento). El ranking de la liga usa
`Quiniela.ranked(tournament, user_ids: liga.member_ids)`. **Cero puntaje nuevo.**

Los miembros sin quiniela todavía no aparecen con puntos: para que figuren en el
ranking con 0, el ranking de la liga parte de los miembros y hace `left join`/merge
con sus quinielas; en la práctica reutilizamos el render existente, así que un
miembro sin quiniela se trata como 0 puntos. (Si un miembro nunca creó quiniela,
igualmente se le crea una vacía al visitar "Mi Quiniela", como ya ocurre hoy.)

## Pantallas y rutas

```ruby
resources :ligas, only: %i[index new create show destroy] do
  collection { post :join }
  member { delete :leave }
end
delete "ligas/:id/members/:membership_id", to: "ligas#expel", as: :liga_member
```

- **index** (`/ligas`): mis ligas (las que integro) + botón "Crear liga" + formulario
  "Unirme con código".
- **new/create**: formulario nombre + cupo (`max_players`).
- **show** (`/ligas/:id`): **solo miembros**. No-miembros → redirigidos a `index`
  con alerta. Muestra:
  - El `invite_code` (con copia) a los miembros.
  - El ranking filtrado (reutiliza el partial `rankings/_table`).
  - Al creador: controles para expulsar a cada miembro y borrar la liga (si está solo).
  - A los demás: botón "Salir".
- **destroy / leave / expel / join**: acciones según reglas anteriores.

Navegación: agregar enlace "Ligas" en la `nav` del layout, junto a "Ranking".

Todas las acciones bajo `before_action :require_login`.

## Validaciones / mensajes (español)

- `name` presente (3–40); `max_players` 2..50; `invite_code` presente y único.
- Mensajes de error definidos en cada acción según la lista de reglas.

## Tests

**Modelo `Liga`:** validaciones (nombre, cupo), generación de `invite_code` único,
`dependent: :destroy` de membresías.

**Modelo `LigaMembership`:** unicidad `[liga_id, user_id]`.

**Quiniela scope:** `ranked` ordena por puntos desc; con `user_ids:` filtra a esos
usuarios; el ranking global sigue igual.

**Request `LigasController`:**
- crear liga (queda como creador y miembro)
- unirse por código; falla por código inválido, duplicado y liga llena
- salir (miembro normal); creador no puede salir
- expulsar (solo creador; no a sí mismo)
- borrar solo si queda solo el creador; bloqueado con otros miembros
- `show` visible solo a miembros; el ranking respeta el orden global filtrado

## Fuera de alcance (YAGNI)

- Invitaciones pendientes / aceptación.
- Regenerar el código de invitación.
- Transferencia de propiedad de la liga.
- Notificaciones por correo.
- Puntaje propio por liga (se reutiliza el global).
