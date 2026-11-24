# T17 — Arranque limpio de la brújula real y aviso háptico de llegada

**Fecha:** 2026-11-24 · **Fase:** F3 (verificación de campo) · **Estado:** hecha (validación en dispositivo pendiente → G5)

## Objetivo
Cerrar dos defectos reportados caminando en el campus: la aguja no reaccionaba al girar en el sitio
con sensores reales, y la llegada al destino no producía ningún aviso perceptible (solo el texto
"Llegaste").

## Qué cambió
- `lib/state/navigation_controller.dart`: bandera `_compassSeedPending` (se arma en `setRealSensors(true)`
  y en el seam `debugUseRealSensors()`); en `_ingestCompass` la primera lectura real hace
  `_filter.reset(_rawHeading)`, fija `_heading` exacto y deja una entrada `brújula · arranque N°` en el
  log. Nuevo `_arrivalHaptic()` (doble `lightImpact` a 120 ms, sin sonido) usado por `_handleArrival()`;
  `_alert()` (impacto fuerte + `SystemSound`) queda solo para la geocerca del Modo B.
- `test/navigation_sensors_test.dart`: captura de `SystemChannels.platform` y 6 tests nuevos.

## Decisiones
- **D-37:** llegada Modo A = vibración ligera doble y silenciosa; el Modo B conserva sonido + impacto
  fuerte. Sin dependencias nuevas (`flutter/services`), sin cambio visual.
- **D-38:** el seed 278° del pasa-bajas es solo de la demo; en Real la primera lectura fija el rumbo.
  `pauseSensors`/`resumeSensors` no rearman la bandera.

## Verificación real
- `dart format .` → 41 archivos, 0 cambios.
- `flutter analyze` → `No issues found!`
- `flutter test` → **128/128** (122 previos + 6 nuevos).
- Sin build Android ni ejecución en dispositivo en esta tarea.

## Pendientes y riesgos
- **Campo:** confirmar que la aguja responde al primer giro real y que el doble impacto se percibe.
  El SM-A065M sigue sin *rotation vector* (D-36), así que σ < 5° espera otro terminal.
- **T16 abierto:** la imprecisión de posición es del GPS + `FixGate ≤ 30 m`; endurecerlo o pasar a
  `LocationAccuracy.best` es decisión GD, no se tocó.
- **T15 abierto:** `Ver mapa OSM` → `Bad state: No element`, falta stack trace de campo.
- El test que ejercita `setRealSensors(true)` toca los plugins sin mock; pasa, pero si algún día
  ensucia el runner se sustituye por el seam `debugUseRealSensors()`.

## Para retomar
- `docs/STATE.md` (tablero: T15–T17, G5) — obligatorio.
- `docs/08-verificacion-campo.md` (protocolo G5σ/G5b/T07) — obligatorio antes de salir a campo.
- `lib/state/navigation_controller.dart` §`_ingestCompass`/`_handleArrival` — solo si se revisa el fix.
