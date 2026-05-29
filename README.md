# ⚽ MiquiMundi — Mi Quiniela Mundialista 2026

Plataforma de quiniela del Mundial 2026 entre amigos: arma tus predicciones, compite y sigue el ranking global en vivo.

Construida con **Ruby on Rails 8 + Hotwire (Turbo/Stimulus) + Tailwind CSS + PostgreSQL**.

## Características

- **Login solo con correo** (sin contraseña) + elección de selección favorita (bandera en el ranking).
- **Fase de grupos:** ordena los 4 equipos de cada grupo arrastrándolos; elige los **8 mejores terceros**.
- **Premios individuales:** Balón de Oro, Bota de Oro, Guante de Oro, Mejor joven, Fair Play (con buscador de jugadores).
- **Eliminatorias:** bracket oficial 2026 completo (Dieciseisavos → Final + 3er puesto); se abre al terminar la fase de grupos y se predicen marcadores reales.
- **Ranking global en vivo** (Turbo Streams) con tarjeta destacada para el líder.
- **Bloqueos automáticos:** la quiniela de grupos se congela al iniciar el Mundial; cada partido de eliminatorias se cierra a su hora de inicio.
- Tour de onboarding, countdown al Mundial, hora de Chile, diseño "vibrante festivo".

## Modelo de puntaje

| Concepto | Puntos |
|---|---|
| Equipo clasificado (1º/2º) | 3 c/u |
| Orden exacto del grupo | +2 |
| Mejor tercero acertado | 3 c/u |
| Marcador exacto (eliminatorias) | 5 |
| Ganador con marcador errado | 2 |
| Clasificado por penales | 3 |
| Multiplicadores | Cuartos ×1.5 · Semis ×2 · Final ×3 |
| Premios | Balón 10 · Bota 10 · Guante 8 · Joven 6 · Fair Play 5 |

## Puesta en marcha

```bash
bin/setup                 # instala dependencias y prepara la base de datos
bin/rails db:seed         # carga el Mundial 2026 (grupos, equipos, bracket)
bin/rails server          # http://localhost:3000
```

## Cargar resultados reales

Edita `db/results.yml` y corre:

```bash
bin/rails quiniela:load_results   # aplica resultados, recalcula puntajes y actualiza el ranking
```

La arquitectura está desacoplada (`ResultsProvider`) para integrar a futuro una API/scraping sin rehacer la base.

## Tests

```bash
bin/rails test
```
