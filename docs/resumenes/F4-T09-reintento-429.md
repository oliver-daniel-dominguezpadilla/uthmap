# F4 · T09 — Reintento único en 429 con `Retry-After` corto

**Fecha:** 2026-11-23 · **Tarea:** T09 · **Estado:** hecha

## Objetivo
Que un 429 transitorio de Orionis (servidor pidiendo esperar ≤ 2 s) no degrade el arranque a `offline`: un reintento y, si vuelve a fallar, el mismo camino de siempre.

## Qué cambió
- `lib/data/campus_api.dart`: parámetro opcional `sleep` (`Future<void> Function(Duration)`, por defecto `Future.delayed`), `_maxRateLimitRetry = 1`, GET extraído a `_get(path, deviceId)` y bucle de máximo 2 intentos en `_getJson`.
- `test/campus_api_test.dart`: 6 tests nuevos (reintento con éxito, reintento que vuelve a fallar, `Retry-After` > 2 s, 429 sin cabecera, 200 directo, 500 sin reintento).

## Decisión
- D-30 · El reintento es **solo** para 429, **uno solo**, y **solo** si `Retry-After ≤ 2 s`; al superar ese umbral se lanza `RateLimitedException` de inmediato para no alargar el arranque (invariante 4: un 429 nunca bloquea la UI). El `X-Device-Id` se resuelve una vez y se reutiliza en el reintento. No hay backoff exponencial ni reintento por 5xx/timeout.

## Verificación real
- `dart format .` → 38 archivos, 0 cambiados.
- `flutter analyze` → "No issues found!".
- `flutter test` → **102/102** (96 + 6); `campus_api_test.dart` pasa de 11 a 17 casos.

## Pendientes
- Verificación contra Orionis real en dispositivo (G3): el reintento no se puede probar con `MockClient`.
- Commit pendiente junto a T08 y los docs actualizados.

## Riesgos abiertos
- Si el backend responde 429 con `Retry-After` en fecha absoluta en vez de segundos, `_parseRetryAfter` ya lo interpreta como `Duration`; cualquier formato no reconocido → `null` → sin reintento (comportamiento conservador).

## Para retomar
- `docs/01-api-contract.md` §429 — contrato de errores (obligatorio si se toca la API).
- `docs/STATE.md` — estado y puertas.
