# Campus Compass — Contexto base (se carga en cada sesión; mantener corto)

Prototipo Flutter **UthMap** (navegación de campus por brújula + geocercado), proyecto existente en `C:/proyectos_flutter/uthmap` (paquete `uthmap`, host Windows). Baseline 100% local y simulado; la etapa actual lo evoluciona a datos reales (API Orionis, `docs/01`) y sensores reales (Android primero) **sin alterar la fidelidad al wireframe** (tema blanco, `#0055FF`, Space Grotesk/Mono). No hay backend propio. Sin SDKs de mapas de pago.

## Roles (mismo modelo, distinto prompt)
- `arquitecto` (primary, Tab): analiza, diseña, escribe specs en `docs/`, descompone en tareas atómicas, revisa diffs. No toca `lib/` ni `test/`.
- `operador` (subagent, `@operador`): implementa UNA tarea atómica, corre tests, devuelve reporte. No rediseña.

## Documentos (leer bajo demanda, no todos a la vez)
| Archivo | Cuándo leerlo |
|---|---|
| `docs/00-spec.md` | Requisitos, niveles 7/8/9, extras, trazabilidad RF-xx |
| `docs/01-api-contract.md` | Cualquier código que consuma la API |
| `docs/02-algoritmos.md` | Haversine, bearing, cuadrantes, filtro pasa-bajas, tests con vectores |
| `docs/03-arquitectura-movil.md` | Estructura de carpetas, interfaces, modelos |
| `docs/04-design-system.md` | Cualquier UI (tokens, pantallas, reglas anti-slop) |
| `docs/05-workflow.md` | Plantillas de tarea/reporte, fases, DoD |
| `docs/06-orquestacion.md` | Protocolo Arquitecto↔Operador y puertas humanas (obligatorio para el Arquitecto) |
| `docs/07-baseline-prototipo.md` | Qué ya existe en el código, convenciones de test, brechas |
| `docs/STATE.md` | Tablero de tareas, puertas y decisiones (lo edita solo el Arquitecto) |
| `docs/source/` | Fuentes originales (PDF de requisitos, manual HTML de endpoints). Solo ante discrepancia |

Skills (cargar con la tool `skill`): `anti-ai-slop-uiux`, `component-reference-design`, `ui-ux-pro-max`, `android-design-guidelines`, `ios-design-guidelines`, `mobile-app-ui-design` (solo para UI).

## Comunicación y pausas
- Arquitecto delega al subagente `operador`; el reporte del Operador regresa solo al Arquitecto.
- Solo el Arquitecto habla con el usuario (herramienta `question`). Se detiene en las puertas G0–G5, GD, GB, GC de `docs/06-orquestacion.md`.
- Arranque autónomo: `/orquestar`. Consulta rápida: `/estado`.

## Resúmenes de bloque (obligatorio)
Todo bloque de trabajo cierra con un `.md` en `docs/resumenes/` + una línea en `docs/resumenes/INDEX.md`. Lo escribe siempre el Arquitecto, nunca el Operador. Confinado a esa carpeta: sin resúmenes en otro sitio ni carpetas nuevas. Se genera al cerrar una tarea no trivial (≥3 archivos o con decisión), una fase, un bloque de ≥3 tareas y toda decisión GD/GB. Regla completa en `docs/06-orquestacion.md` §"Resúmenes de bloque".

## Invariantes (no negociables)
1. Haversine con R = 6 371 000 m. Bearing con `atan2`. Aguja = `(bearing - heading) mod 360`.
2. Proximidad (Modo B) = `radio_cobertura` del edificio (default 20 m). Llegada (Modo A) = `min(15, radio_cobertura)` m.
3. Modo A orienta solo a `ENTRADA_*`; Modo B evalúa todos los puntos, incluido `PERIMETRO`.
4. Tras la sincronización inicial la app funciona 100% offline (datos + imágenes cacheadas). Un 429 nunca bloquea la UI.
5. Enviar siempre `X-Device-Id` (UUID persistido). Sin auth, sin tokens.
6. Funciones geodésicas puras (en el prototipo: `lib/core/geo.dart`, `lib/core/geofence.dart`), sin Flutter ni sensores. No refactor masivo: extender lo existente.
7. El wireframe manda en lo visual (`docs/04`). Cualquier cambio visual es puerta GD/G2. Conservar los 20 tests y las capturas de `docs/screenshots/`.
8. Tests de widgets: `rootBundle.loadString(..., cache: false)` y pumps explícitos (10–12 × 100 ms), no `pumpAndSettle()`.
9. No usar builds web en el bucle de trabajo (5–8 min). Validación = `flutter test` + Android físico.

## Comandos
```
flutter pub get
dart format .
flutter analyze
flutter test
```

## Definition of Done (por tarea)
`flutter analyze` sin warnings · `flutter test` verde · tests nuevos para lógica nueva · criterios de aceptación de la tarea verificados · reporte entregado según `docs/05-workflow.md`.

## No inventar
Si una API, paquete o campo no está en `docs/`, no lo asumas: devuelve la duda o verifica en la documentación oficial.
