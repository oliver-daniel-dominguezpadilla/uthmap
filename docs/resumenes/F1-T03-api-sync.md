# F1-T03 — Cliente Orionis y sincronización real

Fecha: 2026-11-21 · Tareas: T03a + T03b · Estado: cerradas

## Qué se hizo

- **T03a — `CampusApi`** (`lib/data/campus_api.dart`): cliente HTTP de solo lectura con `Accept: application/json` y `X-Device-Id`; UUID v4 persistido en `SharedPreferences` (`uthmap.deviceId.v1`) resuelto una sola vez por instancia (`ensureDeviceId`). Timeout de 10 s (`--dart-define=ORIONIS_BASE_URL` para la base). Errores tipados: `CampusApiException` (red, HTTP, JSON, `success != true`) y `RateLimitedException` (429 + `Retry-After`).
- **T03b — `CatalogRepository.syncRemote`** (`lib/data/catalog_repository.dart`): `/ultima_actualizacion` → comparación con el `api_timestamp` guardado → solo entonces `/sincronizar_v2`. Persiste la **envoltura cruda** en una única clave `uthmap.catalogV2.v1` (`saved_at`, `api_timestamp`, `payload`), de modo que el reemplazo del catálogo es un solo `setString` (atómico). `SyncResult` devuelve `actualizado` / `sinCambios` / `offline` con el catálogo local intacto; nunca lanza. `CampusApi.fetchCatalogPayload()` expone la envoltura validada y `fetchCatalog()` se apoya en ella.

## Decisiones tomadas al revisar

- Persistir el payload crudo y re-mapear con `catalogFromSincronizarV2` en cada carga (coherente con D-15): evita `toJson` sobre `Building`/`Catalog` y cualquier DTO paralelo.
- `sinCambios` no descarga el catálogo: un `GET` por arranque cuando no hay cambios (cuota de 100 req/min).
- `clearLocal()` también borra la clave v2; las claves legacy (`uthmap.catalog.v1`, `uthmap.syncedAt.v1`) se conservan y solo se leen como fallback.
- `catch (_)` en la lectura local: un payload corrupto debe degradar a legacy o `null`, no reventar el arranque; el 429 sigue viajando tipado en `SyncResult.error`.

## Verificación

`dart format` sin cambios · `flutter analyze` sin issues · `flutter test` **58/58** (51 previos + 7 de `test/catalog_repository_sync_test.dart`), con fixture real de Orionis.

## Pendiente que arrastra

- La UI sigue usando `sync()` simulado: el cableado a `syncRemote` y el indicador de estado son **T04** (exige GD por la caché de imágenes/video).
- T03b está sin commitear: el commit lo hace el humano en GC.
