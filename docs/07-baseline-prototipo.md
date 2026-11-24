# 07 — Baseline y estado real del prototipo UthMap

**Actualizado el 2026-11-23** (cierre T05d, commit `ba08207`). A0 (2026-11-21) sigue siendo la auditoría base; aquí se refleja lo que ya se construyó encima.
Método: lectura estática del Arquitecto + `flutter test` real ejecutado por el Operador (96/96) y `flutter analyze` limpio.

## Estado verificado
- Proyecto `C:/proyectos_flutter/uthmap`, paquete `uthmap`, host Windows. **26 archivos `.dart` en `lib/`, 11 en `test/`, 96 casos de test.**
- Cliente HTTP real: `CampusApi` contra `https://orionis.osoware.com/api/v1` (`/ultima_actualizacion`, `/sincronizar_v2`), cabecera `X-Device-Id` (UUID persistido), timeout 10 s, 429 con `Retry-After`.
- Catálogo: dos fuentes. **Bundled** `assets/data/edificios.json` (5 edificios, 30 coordenadas, `radio_cobertura_m` 20). **Remoto v2** parseado por `catalog_v2_mapper.dart` a los modelos existentes (`Catalog.originLat/Lng`, `Catalog.skipped`, `MapFootprint?` nullable).
- Persistencia (`shared_preferences`): `uthmap.catalogV2.v1` (payload crudo v2), `uthmap.catalog.v1`, `uthmap.syncedAt.v1`, `uthmap.declination.v1`, UUID de dispositivo.
- Sensores reales: `geolocator` 14 + `flutter_compass` 0.8.1 tras toggle del panel; simulación intacta como modo demo. `FixGate` descarta fixes imprecisos/viejos/saltos; 3 rechazos seguidos → `noSignal`. `pauseSensors`/`resumeSensors` en `app.dart`.
- Media: `MediaCache` (memoria + `DefaultCacheManager`) para `photoUrl`/`videoUrl` remotos, con fallback a `photoAsset`/`videoAsset`; `BuildingPhoto` en ficha, directorio y panel; `video_sheet` reproduce remoto o cae en su vista de error. **Sigue sin existir `assets/videos/`** (D-10).
- Sincronización en arranque: `syncRemote()` reemplaza al sync simulado; offline sin catálogo local → bundled; snackbar único de 3 s.

## Inventario real de `lib/`
| Capa | Archivos |
|---|---|
| Entrada | `main.dart`, `app.dart` |
| `core/` (puros) | `geo.dart`, `geofence.dart`, `sensor_quality.dart` (`FixGate`, `applyDeclinationDeg`, `SensorLog`) |
| `data/` | `models.dart`, `catalog_v2_mapper.dart`, `catalog_repository.dart`, `campus_api.dart`, `media_cache.dart`, `sensor_prefs.dart`, `device_id.dart` |
| `state/` | `navigation_controller.dart`, `nav_state.dart` |
| `ui/` | `theme.dart`, `welcome_screen.dart`, `navigation_screen.dart`, `directory_screen.dart`, `detail_screen.dart`, `credits.dart` |
| `ui/widgets/` | `primitives.dart`, `isometric_map.dart`, `nav_sheet.dart`, `sensor_panel.dart`, `video_sheet.dart`, `osm_map_view.dart`, `building_photo.dart` |

## Contratos y constantes vigentes
- `geo.dart`: `earthRadiusM = 6371000`; `haversineM`; `initialBearingDeg` con `atan2`; `needleAngleDeg = normalize(bearing − heading)`; cuadrantes; `LowPassAngle(alpha)`; `projectToCampus`/`campusPoint` con **`origin` inyectable** (por defecto 19.0, −98.2); `moveBy`, `nearestOf`, `metersPerDegLngAt`.
- `geofence.dart`: entra con `≤ radio`, sale con `> radio + 5`. `arrivalRadiusM(radio) = min(15, radio)` (invariante 2).
- `nav_state.dart`: `NavMode {explore, directed}`, `SensorStatus {ok, denied, disabled, noSignal, uncalibrated}`, `NavState` inmutable.
- `navigation_controller.dart`: tick 300 ms, paso 3 m, `_accuracyLimitM = 30`, brújula `> 15°` de precisión → `uncalibrated`; getter `origin` = origen del catálogo si existe; `_reset()` arranca en `origin`; declinación aplicada a la lectura **cruda** y persistida.
- `catalog_repository.dart`: `loadLocal`, `loadBundled`, `syncRemote() → SyncResult{catalog, status, error, savedAt}` con `SyncStatus {actualizado, sinCambios, offline}`; nunca lanza.

## Dependencias
`http` 1.2 · `uuid` 4.6 · `cached_network_image` 4.0.7 · `flutter_cache_manager` 3.5 · `shared_preferences` 2.5.6 · `geolocator` 14.0.1 · `flutter_compass` 0.8.1 · `flutter_map` 8.3.2 · `latlong2` 0.10.1 · `video_player` 2.14.1 · `chewie` 1.18.1 (D-28).

## Convenciones de test
`rootBundle.loadString(..., cache: false)` y pumps explícitos (10–12 × 100 ms); nunca `pumpAndSettle()`. Servicios inyectados (`MockClient`, `MediaCache(fetch:)`, `SensorPrefs?` nulo en tests): ningún test toca red ni disco.
Archivos: `core_test` (15), `widget_test` (5), `sensor_quality_test`, `navigation_sensors_test`, `sensor_panel_test`, `catalog_v2_mapper_test`, `catalog_repository_sync_test`, `campus_api_test`, `media_cache_test`, `building_photo_test`, `catalog_origin_test` (4 casos: origen del catálogo, `campusPoint(0,0)`, round-trip 40/−30 m, bundled → global). **Total 96.**

## Brechas vivas
1. **Medios por http:** el contrato muestra `foto_url`/`url_video` en `http://`; Android 9+ bloquea cleartext y la caché fallaría en la ficha. Mitigación T08 (cleartext solo en build debug) + pendiente servidor https.
2. **Videos:** sin assets locales; si el payload no trae `url_video`, `video_sheet` muestra su vista de error (comportamiento esperado, no bug).
3. **Declinación:** 0° por defecto; la real se mide en campo (G5) y se fija en el panel. No se inventa.
4. **T07:** video remoto, OSM y filtro α **sin validar en dispositivo**.
5. **Puertas de campo** G3–G6 pendientes.
6. **`docs/` sin versionar** hasta que se aplique D-29 en `.gitignore` (lo edita el humano).

## Limitaciones conocidas
- `video_player` no reproduce en Windows desktop; OSM requiere red (`tile.openstreetmap.org`).
- La entrada secundaria de K está en n=−57, e=139 para que la principal (145 m / 123°) sea la más cercana: dato de demo.
- Compilación web 5–8 min en esta máquina: no usar en el bucle (U7).
- Catálogo real: edificios sin ninguna coordenada se excluyen (`Catalog.skipped`, D-20) y la huella isométrica se deriva del perímetro (`alto` constante, D-21).
