# Anti-bot en el registro — Diseño

**Fecha:** 2026-05-31
**Estado:** Aprobado para plan de implementación

## Problema

El registro (`SessionsController#create`) es ultra-liviano: solo pide **username**
(+ equipo favorito opcional), sin email ni contraseña. El reingreso es por enlace
personal con token. No hay ninguna protección anti-bot ni rate limiting.

Un atacante puede scriptear `POST /session` con usernames aleatorios y:
- Crear masivamente cuentas falsas que ensucian el ranking.
- Saturar la base de datos.

Además, un usuario puede hacer **múltiples clicks seguidos** en "Crear" y disparar
envíos duplicados.

## Objetivo

Frenar bots y la creación rápida/masiva de cuentas **sin fricción visible y sin
dependencias de terceros** (decisión del usuario: solo mecanismos invisibles,
Rails nativo). Las IP compartidas (familia/WiFi) son **muy comunes**, así que el
rate limiting por IP debe ser **generoso**; el peso anti-bot lo llevan el honeypot
y la trampa de tiempo.

## No-objetivos (YAGNI)

- CAPTCHA visible o invisible de terceros (reCAPTCHA / hCaptcha / Turnstile).
- Verificación por email/SMS.
- Bloqueos permanentes de IP o baneos persistentes.
- Protección del endpoint de reingreso (`restore`): el token es `has_secure_token`
  (~140 bits), inviable de adivinar; queda fuera de alcance.

## Diseño — Defensa en profundidad (4 capas)

### Capa 1 — Honeypot (bots que autocompletan formularios)

- Campo oculto en el form de registro, ej. `nickname`, con `tabindex="-1"`,
  `autocomplete="off"`, `aria-hidden="true"` y oculto vía clase CSS
  (posicionado fuera de pantalla, **no** `display:none` para que algunos bots
  igual lo llenen).
- Un humano nunca lo ve ni lo llena; muchos bots completan todos los inputs.
- En `create`: si el honeypot llega **con valor** → no se crea el usuario y se
  responde con un mensaje **genérico** ("No se pudo completar el registro,
  recargá la página e intentá de nuevo") **sin revelar** que es un honeypot.
- Honeypot **vacío o ausente** → se trata como legítimo (un form viejo cacheado
  sin el campo no debe bloquear a un humano).

### Capa 2 — Trampa de tiempo (submits instantáneos/scripteados)

- Al renderizar el form (`new`), se incrusta un **timestamp firmado** en un campo
  oculto, usando `Rails.application.message_verifier(:signup)` (no falsificable).
- En `create` se verifica:
  - Firma inválida / campo ausente / **vencido** (> 2 h) → no crea, mensaje
    "El formulario expiró, recargá la página".
  - Tiempo transcurrido **< 2.5 s** → es un bot, se rechaza (mensaje genérico).
  - Tiempo ≥ 2.5 s y ≤ 2 h → válido.
- Es server-side de punta a punta, así que no hay problema con el reloj del cliente.

### Capa 3 — Rate limiting por IP

Dos mecanismos complementarios (ambos sobre `Rails.cache`):

1. **Contador de cuentas creadas (cuenta solo ÉXITOS)** — clave por IP en cache:
   - **3 por 30 s** y **10 por hora** por IP.
   - Se incrementa **solo cuando `user.save` tiene éxito**, de modo que los
     errores de validación (username repetido/corto/ofensivo) **no** consumen el
     límite ni bloquean a un humano que se equivoca al escribir.
   - Antes de crear: si la IP ya alcanzó cualquiera de los dos topes → 429 +
     flash "Demasiados registros desde tu red, esperá un momento".
2. **Guarda de peticiones crudas** — `rate_limit` nativo de Rails 8 sobre la
   acción `create`: **20 por minuto** por IP → 429. Generoso para no bloquear
   humanos; respaldo anti-martilleo que cuenta todas las peticiones.

IPs distintas mantienen contadores independientes. Los límites son holgados a
propósito porque varias personas comparten WiFi/NAT.

### Capa 4 — Anti doble-click (cliente)

- El botón "Crear" se deshabilita al enviar mediante
  `data: { turbo_submits_with: "Creando…" }` (Turbo), evitando envíos múltiples
  por clicks repetidos.
- Respaldo en servidor: el contador de ráfaga (3/30 s).

## Orden de evaluación en `create`

1. **Guarda cruda** (`rate_limit` de Rails, vía filtro) → 429 si excede.
2. **Honeypot** lleno → rechazo silencioso (no crea).
3. **Trampa de tiempo** inválida/rápida/vencida → rechazo.
4. **Contador de cuentas por IP** alcanzado → 429.
5. Construir `User`, validar y `save`.
6. En éxito: **incrementar** el contador de cuentas de la IP; iniciar sesión y
   redirigir como hoy.

Los rechazos de honeypot/trampa/validación **no** incrementan el contador de
cuentas creadas.

## Componentes y archivos

- `app/controllers/sessions_controller.rb` — lógica de las capas 1-3 en `create`;
  generar timestamp firmado en `new`. Extraer la lógica a un objeto/concern para
  mantener el controlador legible:
  - `app/controllers/concerns/signup_protection.rb` (o un PORO
    `app/services/signup_guard.rb`) que encapsule: verificación de honeypot,
    verificación del timestamp firmado, y el contador de cuentas por IP.
    Interfaz clara y testeable de forma aislada.
- `app/views/sessions/new.html.erb` — campo honeypot oculto, campo timestamp
  firmado, `turbo_submits_with` en el botón.
- `config/environments/production.rb` — `config.cache_store = :solid_cache_store`.
- Instalación de **solid_cache** (`bin/rails solid_cache:install`): migración de la
  tabla de cache + config. Sin dependencias externas (es DB-backed).

## Configuración de cache por entorno

- **Producción:** `:solid_cache_store` (DB) — necesario para que los contadores y
  `rate_limit` funcionen entre procesos/requests.
- **Desarrollo:** `:memory_store` (ya configurado) — suficiente (un solo proceso).
- **Test:** `:null_store` (ya configurado). Los tests que verifican rate limiting
  **sobrescriben** `Rails.cache` con `ActiveSupport::Cache::MemoryStore.new`
  durante el test.

## Manejo de errores / UX

- Honeypot/trampa rápida → mensaje **genérico** (no delata el mecanismo),
  `render :new, status: :unprocessable_entity`.
- Timestamp vencido/ausente → "El formulario expiró, recargá la página",
  `render :new, status: :unprocessable_entity`.
- Rate limit excedido → flash "Demasiados registros desde tu red, esperá un
  momento", `status: :too_many_requests` (429).
- Errores de validación normales (username) → comportamiento actual, sin cambios.

## Plan de pruebas

### Casos felices y de bots (request/integration specs)

1. Honeypot **lleno** → `assert_no_difference("User.count")` + mensaje genérico.
2. Honeypot vacío + timestamp válido (`GET new`, luego `travel 3.seconds`) →
   **crea** el usuario e inicia sesión.
3. Submit **muy rápido** (elapsed ~0) → no crea.
4. Timestamp **ausente** → no crea, mensaje "expiró".
5. Timestamp **forjado** (firma inválida) → no crea.
6. Timestamp **vencido** (`travel 3.hours`) → no crea, mensaje "expiró".

### Rate limiting (con `Rails.cache` sobrescrito a `MemoryStore`)

7. Crear **3 en 30 s** → OK; la **4ª** → 429. Tras `travel 31.seconds` →
   vuelve a permitir.
8. **11ª** cuenta dentro de 1 h → 429.
9. **Dos IPs** distintas (stub de `remote_ip`) → contadores independientes.
10. **Errores de validación** (username repetido/corto) repetidos **no**
    consumen el contador de creación (la siguiente creación válida funciona).
11. Guarda cruda: **> 20 peticiones/min** desde una IP → 429.

### Regresión

12. Actualizar `test/controllers/sessions_controller_test.rb`: agregar un helper
    de test que haga `GET new_session_path`, extraiga el timestamp firmado del
    HTML (o lo genere con el verifier), y POSTee con honeypot vacío + timestamp
    válido + `travel` suficiente. Todos los tests de registro existentes deben
    pasar con el flujo nuevo.
13. La suite completa (98+ tests) queda en verde.

## Riesgos y limitaciones aceptadas

- Un bot **dedicado** que respete el delay de 2.5 s, deje el honeypot vacío y
  **rote IPs** puede crear hasta 10 cuentas/hora por IP. Es el límite consciente
  de "solo invisible, sin terceros". Si más adelante hace falta, se puede sumar
  Cloudflare Turnstile como capa 5 sin rehacer lo anterior.
- Un humano que tarde **más de 2 h** con el form abierto deberá recargar.
