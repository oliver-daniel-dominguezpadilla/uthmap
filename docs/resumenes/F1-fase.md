# F1 — Cierre de fase (auditoría, config y datos reales)

- **Fecha:** 2026-11-21
- **Fase:** F0 (A0 + CFG-02) y F1 (T01, T02) cerradas; T03a entregada sin revisar
- **Estado:** G0 y G1 aprobadas

## Objetivo de la fase
Pasar del prototipo declarado a un baseline verificado y a la puerta de entrada de los datos reales, sin tocar la UI ni el wireframe.

## Qué se completó
- **A0:** `docs/07` reescrito contra el código real (20 `.dart`, 5 edificios/30 coordenadas, 6 discrepancias). Sin ejecutar analyze/test.
- **CFG-02 + bis:** regla de resúmenes en `AGENTS.md`; `deny` en `git commit`, borrados y autoedición de `.opencode/*`/`AGENTS.md`; `steps: 16`/`steps: 24`.
- **T01:** `arrivalRadiusM` = `min(15, radio_cobertura)` en `core/geofence.dart`, consumida por el controlador; +10 tests con los vectores de `docs/02`.
- **T02:** `catalogFromSincronizarV2` + fixture real de `https://orionis.osoware.com/api/v1/sincronizar_v2` (5 851 B); `footprint` nullable, `photoUrl`/`videoUrl`, `Catalog.originLat/originLng/skipped`; +10 tests.
- **T03a (sin revisar):** `CampusApi` (`/ultima_actualizacion`, `/sincronizar_v2`), `X-Device-Id` persistido, `RateLimitedException` con `Retry-After`; dependencias `http` y `uuid` añadidas.

## Decisiones
D-09 llegada por cobertura · D-12/D-19 `steps` y autoedición · D-13 fixture real antes que parser · D-14 T05+T06 fusionadas · D-15…D-17 capa de mapeo aparte · D-18 commit base · D-20…D-23 datos reales (edificios sin coordenadas, huella nullable, origen por catálogo, enum de categorías intacto).

## Verificación real acumulada
`flutter analyze` sin issues en cada tarea · `flutter test`: 20 → 30 (T01) → 40 (T02) → 51 (T03a), todo verde. Ninguna ejecución en dispositivo: G3–G6 pendientes.

## Hallazgos que condicionan F2+
- El payload real trae **5 edificios, 2 sin coordenadas** (se excluyen, `skipped == 2`) y **ninguno con `mapa`**.
- **`foto_url` y `url_video` son `null` en todos**: T04 se validará con URLs sintéticas; la media real espera a G6.
- El campus real está a ~1 400 km del origen fijo de `core/geo.dart`: `originLat/originLng` ya se calculan pero **no están cableados** (T04).

## Pendientes para la próxima sesión
1. Revisar T03a (leer `campus_api.dart` y `device_id.dart` contra sus 5 criterios) y cerrarla.
2. T03b: `CatalogRepository.syncRemote` (comparar timestamp, reemplazo atómico, 429/offline).
3. T04: `cached_network_image`, cableado de origen al mapa y a `_exploreRoute`, indicador de sync.
4. G3 → T05 (sensores + calibración) → G4/G5 → T07/G6.
5. Commits pendientes (GC): CFG-02-bis, T01, T02, T03a.

## Riesgos abiertos
- `_BuildingDraft` lanza `TypeError` si un acceso viene sin `latitud`/`longitud`; `CampusApi` envuelve el error, pero conviene un mensaje explícito.
- El mapa isométrico del catálogo real solo dibujará el edificio E (los demás no tienen perímetro suficiente).
- La config nueva (`steps`, `deny`) se carga por sesión: abrir sesión nueva al retomar.

## Documentos para retomar
| # | Archivo | Para qué | ¿Obligatorio? |
|---|---|---|---|
| 1 | `docs/STATE.md` | Tareas, puertas y D-01…D-23 | Sí |
| 2 | `docs/07-baseline-prototipo.md` | Estado real del código | Sí |
| 3 | `docs/01-api-contract.md` §"Observaciones del payload real" | Rarezas verificadas de Orionis | Sí antes de F2 |
| 4 | `docs/06-orquestacion.md` §"Preflight de fase" | Antes de la primera delegación | Sí |
