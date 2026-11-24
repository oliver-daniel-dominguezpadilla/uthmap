# F4 · T10/T10a/T10b — Prefetch real de medios con timeout

**Fecha:** 2026-11-23 · **Tareas:** T10 (+2 correcciones) · **Estado:** hecha

## Objetivo
Que los `url_video` se cachen de verdad al arrancar (invariante 4: offline con medios), sin que una descarga lenta pueda colgar el arranque.

## Qué cambió
- `lib/data/media_cache.dart`: `videoFile(url, {timeout = 20 s})` con `.timeout(...)` → `null` en timeout; `prefetchVideos(catalog, {max = 3, timeout})` descarga en **paralelo** (`Future.wait`), mismo deduplicado y corte por `max`.
- `lib/app.dart`: `unawaited(_mediaCache.prefetchVideos(catalog))` en `_start(catalog)` — segundo plano, sin snackbar ni estado nuevo.
- `test/media_cache_test.dart`: 6 tests (timeout de `videoFile`, paralelismo con `Completer`, `max`, deduplicado, fallo parcial). T10a/T10b corrigieron dos tests que usaban `expectLater(... returnsNormally)` sobre clausuras async: no esperaban el cuerpo y uno dejaba el prefetch corriendo durante `tearDown` (`PathAccessException` en Windows).

## Decisión
- D-33 · Prefetch: máximo 3 videos, en paralelo, 20 s por descarga, siempre `unawaited` tras crear el controlador. Un fallo o timeout se ignora (la ficha degrada a "abrir enlace"). Sin reintentos ni límite de disco.

## Verificación real
- `dart format .` → 39 archivos, 0 cambiados · `flutter analyze` → "No issues found!".
- `flutter test` → **113/113** (0 fallos, 0 skip); `media_cache_test.dart` 12/12.

## Notas de proceso
- T10 agotó `steps` antes de correr tests: la tarea no se aceptó hasta que T10a validó la suite.
- `expectLater` con clausura async es una trampa recurrente en esta suite: no espera el cuerpo. Prohibido en tests nuevos.

## Pendientes
- Verificación en dispositivo: con red, reiniciar y comprobar que un video queda cacheado y reproduce en modo avión (G6).
- Commit pendiente junto a T08, T09, T11 y docs.

## Para retomar
- `docs/06-orquestacion.md` §R3 — el tope de pasos corta tareas que mezclan implementación y validación.
- `docs/STATE.md` — estado y puertas.
