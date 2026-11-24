# F1 · T05d — Origen del catálogo en la proyección (D-26)

**Fecha:** 2026-11-23 · **Tarea:** T05d (reencolada como T05d-verificación) · **Estado:** hecha

## Objetivo
Que el mapa isométrico, la posición de reposo y el recorrido de demo usen el **origen real del catálogo** (`Catalog.originLat/Lng`) y no el origen global fijo de 19.0, −98.2, sin cambiar el diseño del mapa.

## Qué cambió (arrastrado de la sesión interrumpida; la verificación no editó nada)
- `lib/core/geo.dart`: `projectToCampus` y `campusPoint` aceptan `origin` (por defecto el global).
- `lib/state/navigation_controller.dart`: getter `origin`; `_reset()` arranca en `origin`; `_moveAlongRoute` proyecta con `origin`.
- `lib/ui/widgets/isometric_map.dart`: `IsoSiteMap(origin:)` obligatorio y todas las proyecciones internas lo reciben; `shouldRepaint` compara el origen.
- `lib/ui/navigation_screen.dart`: pasa `origin: controller.origin`.
- `test/catalog_origin_test.dart` (nuevo): 4 casos (A origen del catálogo vs >100 km con el global, B `campusPoint(0,0)`, C round-trip 40/−30 m, D catálogo bundled sin origen → global).

## Verificación real
- `dart format .` → 38 archivos, 0 cambiados.
- `flutter analyze` → "No issues found!".
- `flutter test` → **96/96 verde** (92 previos + 4 nuevos); corrida dirigida del test nuevo 4/4.
- Revisión estática del Arquitecto: invariantes 1 y 2 intactos (`earthRadiusM = 6371000`, `needleAngleDeg` con `normalizeDegrees`, `arrivalRadiusM` sin tocar); UI sin cambios de tokens.

## Pendientes
- **GC:** `T03b`, `T04a–c`, `T05a–d` siguen sin commitear.
- **G5** en Android físico: σ < 5° en reposo, aguja a la puerta correcta, llegada ≤ 15 m; medir la declinación real de CDMX (no se inventa).
- T07 (video/OSM/filtro α en dispositivo) sin empezar.

## Riesgos abiertos
- La declinación por defecto sigue en 0°: hasta G5 el rumbo real puede desviarse algunos grados.
- El mapa isométrico depende de que el catálogo traiga origen; con el catálogo bundled (sin origen) sigue usando el global, cubierto por el caso D.

## Para retomar
- `docs/STATE.md` — tablero y puertas (obligatorio).
- `docs/06-orquestacion.md` §Puertas — formato de G5/GC (obligatorio antes de la puerta).
- `docs/02-algoritmos.md` §proyección local — solo si se toca `geo.dart`.
