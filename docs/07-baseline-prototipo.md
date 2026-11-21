# 07 — Baseline: prototipo UthMap existente

**Auditado contra código el 2026-11-21 (A0, solo lectura estática).**
Método: inventario de `lib/`, `test/`, `assets/`, `android/`, `pubspec.yaml` y lectura completa de `core/`, `data/` y `state/`. **No** se ejecutó `flutter analyze` ni `flutter test` (el Arquitecto no tiene shell); el estado "verde" sigue siendo declarado por la sesión anterior.

## Estado verificado
- Proyecto `C:/proyectos_flutter/uthmap`, paquete `uthmap`, host Windows. 20 archivos `.dart` en `lib/`, 2 en `test/`.
- 100% local y simulado: sin cliente HTTP (no hay `http`/`dio` en `pubspec.yaml`), sin `X-Device-Id`, sin caché de imágenes remotas.
- Catálogo: `assets/data/edificios.json` con **5 edificios** (K, L, M, C Cafetería, R Rectoría) y **30 coordenadas** (6 por edificio: 1 `ENTRADA_PRINCIPAL`, 1 `ENTRADA_SECUNDARIA`, 4 `PERIMETRO`). `radio_cobertura_m` = 20 por defecto.
- Persistencia: `shared_preferences` con claves `uthmap.catalog.v1` y `uthmap.syncedAt.v1`.
- Sensores: simulación por defecto **y** una ruta real ya existente (`NavigationController.setRealSensors`) con `geolocator` 14 y `flutter_compass` 0.8, activable desde `sensor_panel` (desktop/compacto).
- Modo demo: `--dart-define=UTHMAP_DEMO=true` o `?demo=1` (web) → carga el JSON incluido y salta la bienvenida.
- Assets: 6 TTF (SpaceGrotesk ×4, SpaceMono ×2) + 5 JPG. **No existe `assets/videos/`.**

## Inventario real de `lib/`
| Capa | Archivos |
|---|---|
| Entrada | `main.dart`, `app.dart` |
| `core/` | `geo.dart`, `geofence.dart` (puros, sin Flutter) |
| `data/` | `models.dart`, `catalog_repository.dart` |
| `state/` | `navigation_controller.dart`, `nav_state.dart` |
| `ui/` | `theme.dart`, `welcome_screen.dart`, `navigation_screen.dart`, `directory_screen.dart`, `detail_screen.dart`, `credits.dart` |
| `ui/widgets/` | `primitives.dart`, `isometric_map.dart`, `nav_sheet.dart`, `sensor_panel.dart`, `video_sheet.dart`, `osm_map_view.dart` |

## Contratos y constantes vigentes
- `geo.dart`: `earthRadiusM = 6371000`; `haversineM`; `initialBearingDeg` con `atan2`; `needleAngleDeg = normalize(bearing − heading)`; `quadrantLabel`/`quadrantHint`; `LowPassAngle(alpha)` con `shortestDeltaDeg` (cruza 359→0); proyección local `campusPoint`/`projectToCampus` (origen 19.0, −98.2); `moveBy`, `nearestOf`.
- `geofence.dart`: `geofenceInside({distanceM, radiusM, wasInside})` → entra con `≤ radio`, sale con `> radio + 5`.
- `nav_state.dart`: `NavMode {explore, directed}`, `SensorStatus {ok, denied, disabled, noSignal, uncalibrated}`, `NavState` inmutable (contrato motor ↔ UI).
- `navigation_controller.dart`: tick 300 ms, paso 3 m, `_arrivalM = 15`, `_accuracyLimitM = 30`, filtro α = 0.15 con semilla 278°. Modo A orienta solo a `entrances`; Modo B recorre `_exploreRoute` y evalúa **todas** las coordenadas.
- `catalog_repository.dart`: `loadLocal`, `loadBundled`, `sync()` (simulado: 850 ms + copia del asset a prefs), `syncedAt`, `clearLocal`.

## Convenciones de test
`rootBundle.loadString(..., cache: false)` y pumps explícitos (10–12 × 100 ms); nunca `pumpAndSettle()`. `test/core_test.dart` = 15 tests (Haversine/rumbo, cuadrantes, geocerca, filtro, catálogo 1:N con el estado 145 m/123°/205° y búsqueda sin acentos). `test/widget_test.dart` = 5 tests (estado inicial del wireframe, avatar/explorar, búsqueda, ficha ⇄ mapa, layout escritorio). Total **20**.

## Discrepancias detectadas en A0 (corregidas aquí)
1. La lista de "archivos clave" citaba 8 de los 20 reales → inventario completo arriba.
2. "videos K/M" **no existen** en el repo ni en `pubspec.yaml` (`assets:` solo declara `assets/data/` y `assets/img/`); el JSON sí referencia `assets/videos/edificio_k.mp4` y `edificio_m.mp4` → `video_sheet` cae en su vista de error. Se conserva el manejo de error (correcto), pero es un hueco de assets real.
3. "Sensores opcionales" era impreciso: la ruta real ya está implementada tras un toggle, sin calibración ni declinación.
4. "Sin servidor" confirmado, pero conviene precisar: **no hay ningún cliente HTTP en el árbol**, así que T03 parte de cero.

## Brechas respecto a la meta (confirmadas)
1. **Red real:** falta `CampusApi` (`ultima_actualizacion` → `sincronizar_v2`), cabecera `X-Device-Id` persistida (UUID), reglas 429/offline y respaldo local con versión. → T02/T03.
2. **Sensores:** falta calibración (declinación configurable), descarte fino de fixes y log de depuración. → T05/T06.
3. **Media remota:** `foto_url`/`url_video` con caché en disco; hoy `photoAsset`/`videoAsset` son paths locales. → T04.
4. **Llegada vs invariante 2:** hoy es `15` fijo; el invariante pide `min(15, radio_cobertura)`. ≈20 m de radio en todo el catálogo lo hace inocuo hoy, pero debe corregirse. → T01 (lógica pura/tests) + T05 (consumo real).
5. **Validación en dispositivo** de video (hoy roto por assets ausentes), OSM y filtro α. → T07.
6. **Pruebas de campo** (G3–G5).

## Limitaciones conocidas
- `video_player` no reproduce en Windows desktop; OSM requiere red (`tile.openstreetmap.org`).
- La entrada secundaria de K está en n=−57, e=139 para que la principal (145 m / 123°) sea la más cercana: dato de demo.
- Compilación web 5–8 min en esta máquina: no usar en el bucle.
