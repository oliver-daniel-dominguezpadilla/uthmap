# F1 · T05 — Sensores reales, calibración y log (parcial: falta T05d)

**Fecha:** 2026-11-22 · **Fase:** F1 · **Puertas:** G2 aprobada (D-25) · GB resuelta (cerrar T05b dentro de T05c)

## Objetivo
Llevar el motor de navegación de la simulación a sensores reales con calidad de datos: descartar fixes imprecisos, aplicar declinación magnética, exponer precisión de brújula y disponer de log de campo; sin tocar el wireframe.

## Qué cambió
| Archivo | Estado | Contenido |
|---|---|---|
| `lib/core/sensor_quality.dart` (nuevo) | hecho | `FixGate` (precisión ≤ 30 m, antigüedad ≤ 5 s, salto ≤ 60 m/2 s), `applyDeclinationDeg`, `SensorLog` acotado; puro, sin Flutter |
| `lib/data/sensor_prefs.dart` (nuevo) | hecho | Declinación persistida en `uthmap.declination.v1`, recorte ±30° |
| `lib/state/navigation_controller.dart` | hecho | Gate con 3 rechazos consecutivos → `noSignal`; declinación sobre lectura cruda; `CompassEvent.accuracy` > 15 → `uncalibrated`; log; `pauseSensors`/`resumeSensors`; hooks de test |
| `lib/app.dart` | hecho | Inyección de `SensorPrefs`, `loadSettings()` sin bloquear, `WidgetsBindingObserver` para pausar/reanudar sensores |
| `lib/ui/widgets/sensor_panel.dart` | hecho | Declinación (−1°/+1°/0), "Brújula ±X°", hoja "Ver log" (mono 10 px, últimas 40 líneas); solo tokens existentes |
| `lib/core/geo.dart` | **sin verificar** | `projectToCampus`/`campusPoint` aceptan `origin` opcional (retrocompatible) |
| `lib/ui/widgets/isometric_map.dart` + `navigation_screen.dart` | **sin verificar** | `IsoSiteMap` recibe `origin: controller.origin`; solo cambia el origen, no la geometría |
| `test/*` | mixto | `sensor_quality_test.dart` (16), `navigation_sensors_test.dart` (6), `sensor_panel_test.dart` (2); **falta `catalog_origin_test.dart`** |

## Decisiones
- **D-25:** panel dentro del modal "Ajustes de sensores" (G2 aprobada): declinación persistida, línea de precisión de brújula y hoja de log; cero cambios en pantallas del wireframe.
- **D-26:** se corrige el origen de proyección (era global 19.0/−98.2 frente a `Catalog.originLat/Lng` del payload real); con catálogo de Orionis el mapa isométrico se desplazaba kilómetros.
- **D-27:** sin dependencias nuevas (`geolocator` 14, `flutter_compass` 0.8.1, `shared_preferences` ya presentes); declinación real de CDMX se mide en G5, no se inventa.
- GB: un rojo por tolerancia (1,2 cm) no justificaba tercer intento aislado → se cerró dentro de T05c.

## Verificación real
- T05a: `flutter analyze` "No issues found"; `flutter test` 84/84.
- T05b+T05c (tras tolerancia 0,01 → 0,02): `dart format .` 0 changed · `flutter analyze` "No issues found" · `flutter test` **92/92** (incluye los 5 de `widget_test.dart` intactos).
- **T05d: sin validación.** Los cambios en `geo.dart`, controlador, `isometric_map` y `navigation_screen` se aplicaron después del último run verde y la sesión del Operador se interrumpió antes de crear `catalog_origin_test.dart` y correr los comandos. Estado del árbol: probablemente compila, **no verificado**.

## Pendientes
1. Crear `test/catalog_origin_test.dart` (proyección con origen de catálogo, `campusPoint(0,0)`, round-trip 40/−30, catálogo bundled → origen global) y correr `dart format .` + `flutter analyze` + `flutter test`.
2. Verificación humana en Android: hoja "Ver log" sobre el modal, fila "Declinación" sin overflow en panel lateral estrecho, ajuste de declinación en campo.
3. Cerrar T05 en `STATE.md` y sumarlo al bloque para GC.

## Riesgos abiertos
- Suite sin reejecutar tras T05d: si `IsoSiteMap` recibe `origin` y algún test construye el widget sin el parámetro, el rojo aparecerá en el próximo run.
- `CompassEvent.accuracy` en Android son valores fijos del plugin: el aviso de "sin calibrar" es orientativo, se valida en G5 (σ < 5° en reposo).
- `pauseSensors` cancela streams: al volver de segundo plano puede tardar en recuperar fix (sin daño, pero G4 lo notará).

## Para retomar
- `docs/STATE.md` — tablero y T05 pendiente. *(obligatorio)*
- `lib/core/sensor_quality.dart` + `lib/state/navigation_controller.dart` — contrato real del gate y del ciclo de sensores. *(obligatorio si se toca T05)*
- `docs/03-arquitectura-movil.md` §"Observabilidad y calidad" y §"Android primero" — log de campo y batería. *(solo si aplica)*
- `docs/06-orquestacion.md` §"Puertas humanas" — G5 es donde se valida σ y llegada real. *(solo si aplica)*
