# F1 — Resumen de sesión (2026-11-21)

Alcance: cerrar F0 y llevar el prototipo UthMap de datos simulados a **datos y sensores reales**, Android primero, sin alterar el wireframe. Protocolo: `docs/06-orquestacion.md`; tablero: `docs/STATE.md`.

## Estado al cierre de la sesión

| Concepto | Estado |
|---|---|
| Fase | F1 (datos reales); T01–T04 cerradas |
| Tests | **68/68** verdes (`flutter test`) |
| Análisis | `flutter analyze` → `No issues found!` |
| Formato | `dart format .` sin cambios pendientes |
| Puertas | G0, G1 aprobadas · GD (`http`, `uuid`, `cached_network_image`, `flutter_cache_manager`) aprobada · G2 (T04) aprobada |
| Commits | Todo F1 desde T03b **sin commitear** (lo ejecuta el humano en GC) |

## Qué se hizo, en orden

1. **CFG-02 / CFG-02-bis — endurecer la config de agentes.** `deny` en `git commit`, borrados, `AGENTS.md` y `.opencode/*`; topes de pasos `arquitecto: 24`, `operador: 16`; regla de resúmenes replicada en `AGENTS.md`. Verificado con analyze limpio y 20/20.
2. **A0 — auditoría de `lib/` y `test/`.** Solo lectura estática; `docs/07` reescrito con inventario real, 20 tests y 6 discrepancias.
3. **T01 — núcleo geodésico.** `arrivalM = min(15, radio_cobertura)` con función pura y vectores de `docs/02`; 30/30.
4. **T02 — parser real de `/sincronizar_v2`.** Fixture real de Orionis (5 851 B) + capa de mapeo `catalogFromSincronizarV2`, sin DTOs ni cambios en `Building.fromJson`; 40/40.
5. **T03a — `CampusApi`.** `Accept: application/json` + `X-Device-Id` (UUID v4 persistido, resuelto una sola vez por instancia), timeout 10 s, `CampusApiException` y `RateLimitedException` con `Retry-After`.
6. **T03b — `CatalogRepository.syncRemote`.** `/ultima_actualizacion` → comparación con el `api_timestamp` guardado → solo entonces `/sincronizar_v2`; payload crudo en una única clave `uthmap.catalogV2.v1` (reemplazo atómico); `actualizado` / `sinCambios` / `offline`; nunca lanza; 429 nunca bloquea.
7. **T04a — `MediaCache`.** `videoFile` sobre `DefaultCacheManager`, `imageProvider` → `CachedNetworkImageProvider`, `prefetchVideos` deduplicado y en serie; fetcher inyectable, 7 tests sin red.
8. **T04b — `BuildingPhoto` y medios en la ficha.** Una sola política de foto (remoto con `CachedNetworkImage`, fallback al asset, placeholder del color actual), video remoto descargado a archivo con fallback al asset, plumbing `main → UthMapApp → NavigationScreen → DetailScreen/VideoSheet`.
9. **T04c — miniaturas y arranque real.** Directorio (64×64) y panel (44×44) con `BuildingPhoto`; CTA de video visible con `videoAsset` **o** `videoUrl`; `WelcomeScreen` usa `syncRemote()` y cae a `loadBundled()`; un único snackbar "Catálogo local · sin conexión" post-frame, solo en `SyncStatus.offline`.

## Archivos nuevos relevantes

- `lib/data/campus_api.dart`, `lib/data/device_id.dart`, `lib/data/media_cache.dart`
- `lib/data/catalog_v2_mapper.dart` (T02)
- `lib/ui/widgets/building_photo.dart`
- Tests: `test/campus_api_test.dart`, `test/catalog_v2_mapper_test.dart`, `test/catalog_repository_sync_test.dart`, `test/media_cache_test.dart`, `test/building_photo_test.dart`, fixture `test/fixtures/orionis_sincronizar_v2.json`

## Decisiones que gobiernan lo hecho

- **D-15** payload/mapeo: el parser v2 es capa aparte; se persiste el **payload crudo** y se re-mapea al cargar. Nada de `toJson` sobre los modelos.
- **D-17** medios: `photoUrl`/`videoUrl` nullable conviven con los assets incluidos; la UI elige remoto si hay URL.
- **D-20/D-21/D-22** edificios sin coordenadas se excluyen y suman a `Catalog.skipped`; huella derivada del perímetro y nullable; origen del campus en el `Catalog`.
- **D-24** precedencia de diseño: **wireframe (`docs/04` + capturas) > invariantes > skills**. De los skills de frontend se adoptan solo reglas neutras (grid 4/8, una familia, máx. 4 tamaños/3 pesos, tap ≥ 44 px, estados vacío/error/carga); se rechazan glow, glass, sparkles, emojis como iconos y Tailwind/Lucide.
- **Snackbar offline** desde la raíz con `scaffoldMessengerKey`: el `State` de `UthMapApp` vive por encima de `MaterialApp`.

## Verificación en dispositivo pendiente

- Nada de lo nuevo se ha ejecutado en Android físico: sync real, caché de medios, 429 y snackbar requieren G5/T07.
- Las capturas de `docs/screenshots/` siguen siendo el patrón de comparación visual.

## Riesgos abiertos

- **Tope de 16 pasos del Operador**: se agotó dos veces en T04b. Mitigación aplicada: partir en tareas de ≤3 archivos y dejar los comandos al final.
- Arranque con red lenta: `syncRemote` puede tardar hasta el timeout (10 s) en el welcome. Aceptable en F1; si molesta en G5 se añade *timeout* de UX o arranque en segundo plano.
- Sin local y offline, el welcome sirve el catálogo incluido pero no persiste nada: el ciclo se repite en cada arranque hasta la primera sincronización con red.

## Siguiente acción

**T05** (alcance confirmado): sensores reales en `lib/state/navigation_controller.dart` — permisos, descarte de fixes por `accuracy`, filtro pasa-bajas de heading, calibración de 8 y log de diagnóstico; sin UI nueva. Propuesta de partición: **T05a** geolocalización + descarte de fixes (testeable sin dispositivo) y **T05b** brújula + calibración + log. Después, T07 y G5.
