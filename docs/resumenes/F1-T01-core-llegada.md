# F1 — T01: `core/` auditado y radio de llegada

- **Fecha:** 2026-11-21
- **Alcance:** `lib/core/geofence.dart`, `lib/state/navigation_controller.dart`, `test/core_test.dart`
- **Estado:** hecha

## Objetivo
Cerrar la brecha entre `docs/02` y el código real, y aplicar el invariante 2 (llegada = `min(15, radio_cobertura)`) sin tocar UI.

## Qué cambió
- `geofence.dart`: nueva función pura `arrivalRadiusM(coverageRadiusM, {arrivalDefaultM = 15})`.
- `navigation_controller.dart`: desaparece `_arrivalM`; `_tick()` y `_onRealPosition()` comparan contra `arrivalRadiusM(_target!.coverageRadiusM)`.
- `core_test.dart`: +10 tests (grupos "Vectores de docs/02" y "Radio de llegada").

## Decisiones
- D-09 ejecutada: el 15 fijo se sustituye por la función pura; con `radio_cobertura` 20 el comportamiento observable no cambia (15 m), así que no hay regresión visual.
- No se renombra nada de `geo.dart` aunque `docs/02` use otros nombres: el doc es referencia, la API real manda.

## Verificación real
- `dart format` sobre los 3 archivos (1 reformateado) · `flutter analyze` → *No issues found!* (79.6 s) · `flutter test` → **30/30 en verde** (20 previos + 10 nuevos).
- Vectores de `docs/02` pasan con las tolerancias del documento, sin ajustarlas: 111194.927 m (ecuador y meridiano), 99.9998/0.0, 99.9997/89.9998, 16.9496/316.7956, filtro 359.3 / 0.7 / 12.0.

## Pendientes
- Verificación en dispositivo (G5/G3): un edificio con cobertura < 15 m debe disparar la llegada al entrar en su cobertura.

## Riesgos abiertos
- Ninguno de código. `test/core_test.dart` crece; conviene no seguir apilando grupos ahí en T02 (usar archivo propio).

## Documentos para retomar
| # | Archivo | Para qué |
|---|---|---|
| 1 | `docs/STATE.md` | Siguiente tarea (T02) y decisiones |
| 2 | `docs/01-api-contract.md` | Forma de `/sincronizar_v2` para el parser |
| 3 | `docs/07-baseline-prototipo.md` | Modelo local de destino (`data/models.dart`) |
