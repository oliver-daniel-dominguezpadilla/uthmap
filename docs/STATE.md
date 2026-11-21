# STATE — Tablero (solo lo edita el Arquitecto)

Fase activa: F0 (A0 hecha, G0 aprobada; CFG-02 en curso)
Alcance: evolucionar el prototipo UthMap a datos y sensores reales. Android primero. Wireframe manda.

## Tareas
| ID | Título | Estado | Reintentos | Notas |
|---|---|---|---|---|
| CFG-02 | Endurecer config de agentes: `steps`, `deny` de commit/borrados/autoconfig, regla de resúmenes en `AGENTS.md` | hecha | 1 | Cerrada con CFG-02-bis. `deny` en commit/borrados/`AGENTS.md`/`.opencode/*`, `steps: 16` / `steps: 24`, analyze limpio y 20/20. Resumen: `docs/resumenes/F0-CFG-02-endurecimiento-aplicado.md` |
| A0 | Auditoría de lib/ y test/ → corregir docs/07 | hecha | 0 | 2026-11-21, solo lectura estática; `docs/07` reescrito con inventario real, 20 tests y 6 discrepancias |
| T01 | Auditar core/geo y geofence vs vectores; `arrivalM = min(15, radio_cobertura)` con tests | hecha | 0 | 30/30 tests, analyze limpio. Resumen: `docs/resumenes/F1-T01-core-llegada.md`. Verificación en dispositivo queda para G5 |
| T02 | Capturar payload real de Orionis como fixture → parser a modelos existentes | hecha | 1 | Fixture real (5 851 B) + `catalogFromSincronizarV2`. 40/40 verde. Resumen: `docs/resumenes/F1-T02-parser-v2.md` |
| T03 | CampusApi + sync + X-Device-Id + 429/offline | pendiente | 0 | Divídida por el tope de 16 pasos: T03a (api + device id) y T03b (sync en repositorio). GD aprobada: `http`, `uuid` |
| T03a | `CampusApi` + `X-Device-Id` + errores 429/timeout, con `MockClient` | en revisión | 0 | REPORTE recibido: 51/51 verde, analyze limpio; falta revisión del Arquitecto |
| T03b | `CatalogRepository.syncRemote` (comparar timestamp, reemplazo atómico, offline) | pendiente | 0 | Depende de T03a |
| T04 | Caché de fotos/videos remotos + indicador de sync | pendiente | 0 | Dependencia nueva → GD antes |
| T05 | Sensores reales + calibración + descarte de fixes + log (T05+T06 fusionadas) | pendiente | 0 | Mismo archivo: `navigation_controller.dart` |
| T07 | Validación de extras en dispositivo | pendiente | 0 | |

Estados: pendiente · en curso · en revisión · hecha · bloqueada.

## Puertas
| ID | Estado | Respuesta del usuario | Fecha |
|---|---|---|---|
| G0 | aprobada | Aprobado con plan ajustado (CFG-02 → T01 ∥ T02 → G1 → T03/T04 con GD → T05 fusionada → T07) | 2026-11-21 |
| G1 | aprobada | Tests verdes (40/40) y UI idéntica a `docs/screenshots/` | 2026-11-21 |

## Decisiones
- D-01 · Modelo único: `opencode-go/deepseek-v4.1-flash` en ambos roles. Origen único en `opencode.json`; el Operador lo declara explícito. El ID anterior (`deepseek-v4-flash`) no existe en el catálogo.
- D-02 · `git commit` denegado al Operador; **el commit lo ejecuta el humano en GC**. Motivo: un "Allow always" sobre `ask` desactivaría GC de forma permanente.
- D-03 · Topes duros de pasos: `arquitecto: 24`, `operador: 16`. Impide bucles de coste.
- D-04 · Borrados (`rm`, `Remove-Item`, `del`) pasan de `ask` a `deny`: un agente de implementación no necesita borrar archivos.
- D-05 · Riesgos R1–R8 y preflight de fase documentados en `docs/06-orquestacion.md`.
- D-06 · Todo bloque de trabajo cierra con un `.md` en `docs/resumenes/` + línea en su `INDEX.md`; lo escribe el Arquitecto. Confinado a esa carpeta: sin carpetas ni archivos de resumen en otro sitio. Se genera al cerrar tarea no trivial, fase, bloque de ≥3 tareas o decisión GD/GB.
- D-07 · La regla D-06 se replica en `AGENTS.md` (pendiente, dentro de CFG-02) para que aplique a cualquier agente futuro, no solo al que lea `docs/06`.
- D-08 · Economía de contexto (R9): la tarea cita archivo + sección, no docs enteros; el Operador no amplía lectura por su cuenta.
- D-09 · Llegada = `min(15, radio_cobertura)` (invariante 2). Hoy el código usa `15` fijo: se corrige en T01 (función pura + tests) y se consume en T05. No se toca UI.
- D-10 · Los videos `assets/videos/edificio_k.mp4` y `edificio_m.mp4` **no existen** ni están declarados en `pubspec.yaml`. Decisión: no fabricar assets; T04 los sustituye por `url_video` remoto con caché y fallback al error actual. G6 valida el resultado.
- D-11 · No hay cliente HTTP en el árbol (sin `http`/`dio`). T03 elige el paquete; cualquier dependencia nueva exige puerta GD antes de T03.
- D-12 · `steps` va en el frontmatter de cada agente (campo V2 válido; `maxSteps` está deprecado). El Operador no puede editar `.opencode/*` ni `AGENTS.md`: la config la cambia el humano o el Arquitecto nunca; evita que un agente en bucle reescriba sus propias reglas.
- D-13 · T02 exige una respuesta real de Orionis guardada como fixture antes de escribir el parser; sin payload no se adivinan campos.
- D-14 · T05 y T06 se fusionan: ambas tocaban `navigation_controller.dart` y partirlas duplicaba ciclos de reporte sobre el mismo bloque.
- D-15 · El parser v2 es una **capa de mapeo aparte** (`lib/data/catalog_v2_mapper.dart` o similar → `Catalog`); `Building.fromJson` se queda intacto para el JSON de assets. Sin clases DTO paralelas ni alias dentro del modelo.
- D-16 · `/sincronizar_v2` no trae `mapa` (huella isométrica). Se deriva del `perimetro` (centro = coordenada central proyectada, ancho/fondo = bbox) con un `alto` constante declarado; si no hay perímetro, el mapa isométrico no se dibuja. No se inventan huellas.
- D-17 · `Building` gana `photoUrl`/`videoUrl` nullable; `photoAsset`/`videoAsset` se conservan para el catálogo incluido. La UI elige remoto si hay URL (T04), local si no.
- D-18 · El repo **no tiene commit base** (todo el árbol sin rastrear). Antes de T01/T02 se hace un commit inicial del estado actual para tener punto de retorno y diffs revisables. Lo ejecuta el humano (GC).
- D-19 · `steps` se aplica a mano: ambos agentes tienen `deny edit` en `.opencode/*`, así que la tarea no puede escribir su propio tope. Edición humana de 2 líneas, no se relaja el `deny`.
- D-20 · Edificios sin ninguna coordenada (A y C en el payload real) se **excluyen** del catálogo navegable y se cuentan en `Catalog.skipped`. Motivo: `mainEntrance` revienta con lista vacía y `osm_map_view` la usa; incluirlos exigiría tocar UI y el OSM view en F1.
- D-21 · Sin `mapa` en la API, la huella se deriva del `perimetro` (bbox proyectada, `alto` = constante visual declarada) y es `null` con menos de 3 vértices. `MapFootprint?` pasa a nullable; el mapa isométrico omite los que no tienen.
- D-22 · El origen del campus deja de ser solo global: `Catalog` lleva `originLat`/`originLng` calculados del propio payload. En F1 solo se almacenan (sin cablear UI); el cableado es T04.
- D-23 · Categoría: el enum conserva 3 valores (cambio de enum = cambio de UI). "Académico"→`academico`, "Administrativo"→`administrativo`, cualquier otra ("Área Común / Convivencia", "Laboratorio / Taller")→`servicios`, documentado como pérdida conocida.
- Wireframe manda sobre el tema oscuro del kit (U6).
- Desarrollo sin web: build web tarda 5–8 min (U7).
