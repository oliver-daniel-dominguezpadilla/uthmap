# STATE — Tablero (solo lo edita el Arquitecto)

Fase activa: F1/F3 cerrada en código; siguiente **T07** tras G5 (campo, Android físico) y GC (commit de T03b–T05d)
Alcance: evolucionar el prototipo UthMap a datos y sensores reales. Android primero. Wireframe manda.
Último commit (GC, 2026-11-21): `feat(f1): llegada por cobertura y parser real de /sincronizar_v2` (CFG-02-bis + T01 + T02 + T03a). Sin commitear: T03b, T04a–T04c, T05a–T05d.

## Tareas
| ID | Título | Estado | Reintentos | Notas |
|---|---|---|---|---|
| CFG-02 | Endurecer config de agentes: `steps`, `deny` de commit/borrados/autoconfig, regla de resúmenes en `AGENTS.md` | hecha | 1 | Cerrada con CFG-02-bis. `deny` en commit/borrados/`AGENTS.md`/`.opencode/*`, `steps: 16` / `steps: 24`, analyze limpio y 20/20. Resumen: `docs/resumenes/F0-CFG-02-endurecimiento-aplicado.md` |
| A0 | Auditoría de lib/ y test/ → corregir docs/07 | hecha | 0 | 2026-11-21, solo lectura estática; `docs/07` reescrito con inventario real, 20 tests y 6 discrepancias |
| T01 | Auditar core/geo y geofence vs vectores; `arrivalM = min(15, radio_cobertura)` con tests | hecha | 0 | 30/30 tests, analyze limpio. Resumen: `docs/resumenes/F1-T01-core-llegada.md`. Verificación en dispositivo queda para G5 |
| T02 | Capturar payload real de Orionis como fixture → parser a modelos existentes | hecha | 1 | Fixture real (5 851 B) + `catalogFromSincronizarV2`. 40/40 verde. Resumen: `docs/resumenes/F1-T02-parser-v2.md` |
| T03 | CampusApi + sync + X-Device-Id + 429/offline | hecha | 0 | Partida en T03a + T03b, ambas cerradas. GD aprobada: `http`, `uuid`. Resumen: `docs/resumenes/F1-T03-api-sync.md` |
| T03a | `CampusApi` + `X-Device-Id` + errores 429/timeout, con `MockClient` | hecha | 0 | Revisión estática del Arquitecto OK: contrato `/ultima_actualizacion` + `/sincronizar_v2`, `X-Device-Id` resuelto una vez por instancia, 429 con `Retry-After`, timeout 10 s, sin excepciones crudas. 51/51 verde, analyze limpio |
| T03b | `CatalogRepository.syncRemote` (comparar timestamp, reemplazo atómico, offline) | hecha | 0 | Revisado: payload crudo v2 en una sola clave (`uthmap.catalogV2.v1`), `sinCambios` sin descargar, 429/500 → `offline` con catálogo local intacto. 58/58 verde, analyze limpio |
| T04 | Caché de fotos/videos remotos + indicador de sync | hecha | 0 | GD y G2 aprobadas. Resumen: `docs/resumenes/F1-T04-medios-sync.md` |
| T04a | `MediaCache`: `videoFile`, `imageProvider`, `prefetchVideos`, inyectable y sin red en tests | hecha | 0 | 7 tests nuevos; fetch por defecto `DefaultCacheManager`, URLs no http(s) descartadas |
| T04b | `BuildingPhoto` + foto/video remotos en ficha y `video_sheet` + plumbing | hecha | 2 | 2 intentos agotados por tope de pasos → re-descompuesta en T04b-1/-2. Fallback a asset intacto; 68/68 verde, analyze limpio |
| T04c | Miniaturas remotas en directorio y panel + `syncRemote` en arranque con snackbar offline | hecha | 0 | `syncRemote` reemplaza al sync simulado; offline sin local → catálogo incluido; snackbar único de 3 s vía `scaffoldMessengerKey` |
| T05 | Sensores reales + calibración + descarte de fixes + log (T05+T06 fusionadas) | hecha | 0 | T05a–T05d cerradas, 96/96 verde, analyze limpio. G2 aprobada. Verificación en dispositivo → G5. Resumen: `docs/resumenes/F1-T05-sensores-reales.md` |
| T05a | Capa pura `lib/core/sensor_quality.dart`: `FixGate`, declinación, `SensorLog` + tests | hecha | 0 | Revisado: sin imports de Flutter, reutiliza `haversineM`/`normalizeDegrees`, 16 tests nuevos, 84/84 verde, analyze "No issues found". Rechazo no mueve la referencia. |
| T05b | Cableado en `navigation_controller.dart`: gate de fixes, declinación persistida, precisión de brújula, ciclo de vida | hecha | 2 | Cerrada dentro de T05c por GB. Gate con 3 rechazos → `noSignal`, declinación sobre lectura cruda, `accuracy` > 15 → `uncalibrated`, `pauseSensors`/`resumeSensors` en `app.dart`. 6 tests |
| T05c | Panel "Ajustes de sensores": declinación, brújula ±X°, hoja de log | hecha | 1 | G2/D-25 aplicada. Declinación −1°/+1°/0, "Brújula ±X°", "Ver log" (mono 10 px, 40 líneas). 92/92 verde, analyze limpio. Verificación en dispositivo → G5 |
| T05d | Origen del catálogo en la proyección (`projectToCampus` + `isometric_map` + posición de espera) | hecha | 2 | Cerrada por T05d-verificación (2026-11-23): código ya correcto, `test/catalog_origin_test.dart` con 4 casos; format/analyze/test limpios, 96/96. Resumen: `docs/resumenes/F1-T05d-origen-catalogo.md` |
| T07 | Validación de extras en dispositivo | pendiente | 0 | |

Estados: pendiente · en curso · en revisión · hecha · bloqueada.

## Puertas
| ID | Estado | Respuesta del usuario | Fecha |
|---|---|---|---|
| G0 | aprobada | Aprobado con plan ajustado (CFG-02 → T01 ∥ T02 → G1 → T03/T04 con GD → T05 fusionada → T07) | 2026-11-21 |
| G1 | aprobada | Tests verdes (40/40) y UI idéntica a `docs/screenshots/` | 2026-11-21 |
| G2 | aprobada | Panel de sensores: declinación persistida, precisión de brújula y hoja de log, sin tocar el wireframe | 2026-11-22 |
| GB | resuelta | "Cerrar T05b dentro de T05c": el rojo por tolerancia (1,2 cm) se arregló en T05c | 2026-11-22 |
| GC | aprobada | Commit de T03b–T05d con mensaje `feat(f1): caché de medios, sync en arranque y sensores reales con origen del catálogo`; el humano lo ejecuta y confirma el hash | 2026-11-23 |

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
- D-24 · Skills de frontend instalados en `.opencode/skills/` (`mobile-app-ui-design`, `android-design-guidelines`, `ios-design-guidelines`, `anti-ai-slop-uiux`, `component-reference-design`, `ui-ux-pro-max`). Precedencia fijada: wireframe (`docs/04` + `docs/screenshots/`) > invariantes de `AGENTS.md` > skill. Del skill se adoptan solo las reglas no visuales o neutras (grid 4/8 para valores nuevos, una familia tipográfica, máx. 4 tamaños / 3 pesos, tap targets ≥ 44 px, estados vacío/error/carga obligatorios); se rechazan las que desvían el wireframe (glow, inner shadows, glassmorphism, sparkles, emojis como iconos, Lucide/Tailwind/Recharts). Cualquier incorporación visual concreta sigue exigiendo G2.
- D-25 · G2 aprobada (2026-11-22): el panel de sensores gana tres elementos dentro del modal existente "Ajustes de sensores", sin tocar las pantallas del wireframe: declinación persistida (`uthmap.declination.v1`, 0 por defecto, ±30° en pasos de 1°), línea "Brújula ±X°" desde `CompassEvent.accuracy` (aviso `uncalibrated` si X > 15) y hoja de log (últimas 40 líneas, `SpaceMono` 10–11 px, formato `HH:mm:ss · evento · dato`). Sin colores, radios ni iconos nuevos.
- D-26 · Bug detectado en la auditoría de T05: `projectToCampus` usa el origen global (19.0, −98.2) mientras las huellas del payload real se derivan de `Catalog.originLat/Lng`; con catálogo de Orionis el mapa isométrico se desplaza kilómetros y `_reset` arranca en una posición inventada. Se corrige en T05d (origen inyectable con valor por defecto, sin cambiar el diseño del mapa).
- D-27 · T05 no añade dependencias: `geolocator` 14, `flutter_compass` 0.8.1, `shared_preferences` y `uuid` ya están en `pubspec.yaml`. Declinación por defecto 0° ajustable en campo (la declinación real de CDMX se mide en G5, no se inventa).
- Wireframe manda sobre el tema oscuro del kit (U6).
- Desarrollo sin web: build web tarda 5–8 min (U7).
