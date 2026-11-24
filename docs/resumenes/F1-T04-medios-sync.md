# F1-T04 — Medios remotos, caché y sincronización en el arranque

Fecha: 2026-11-21 · Tareas: T04a, T04b (+T04b-1/-2), T04c-1, T04c-2 · Estado: cerradas

## Qué se hizo

- **T04a — `MediaCache`** (`lib/data/media_cache.dart`): `videoFile(url)` sobre `DefaultCacheManager` (null si la URL no es http/https o si falla), `imageProvider(url)` → `CachedNetworkImageProvider`, `prefetchVideos(catalog, max)` con deduplicado, descarga en serie y conteo de éxitos. Fetcher y factory de imagen inyectables; 7 tests sin red. Dependencias aprobadas en GD: `cached_network_image 4.0.7`, `flutter_cache_manager 3.5.0`.
- **T04b — `BuildingPhoto`** (`lib/ui/widgets/building_photo.dart`): única implementación de la política de foto. Con `photoUrl` → `CachedNetworkImage` con placeholder del color actual y `errorWidget` al asset; sin URL → exactamente el árbol anterior (`Image.asset` o `ColoredBox`). Aplicado en el hero de la ficha, en `video_sheet` (video remoto desde archivo con fallback al asset) y plumbing `main → UthMapApp → NavigationScreen → DetailScreen/VideoSheet`.
- **T04c — miniaturas y arranque real**: directorio (64×64, `memCacheWidth: 192`) y panel (44×44, `memCacheWidth: 132`) usan `BuildingPhoto`; el CTA de video aparece con `videoAsset` **o** `videoUrl`. `WelcomeScreen` llama a `syncRemote()` y cae a `loadBundled()` si no hay local; `UthMapApp` muestra un único snackbar "Catálogo local · sin conexión" post-frame, solo en `SyncStatus.offline`.

## Decisiones tomadas al revisar

- `mediaCache` se propaga como **opcional** con fallback local en pantalla (`widget.mediaCache ?? MediaCache()`): mantenerlo `required` habría obligado a tocar `directory_screen` y `test/widget_test.dart` en tareas ajenas. `MediaCache` es sin estado, así que el fallback no crea duplicación de datos.
- Snackbar desde la raíz con `scaffoldMessengerKey` (`GlobalKey<ScaffoldMessengerState>`): el `State` de `UthMapApp` vive por encima de `MaterialApp` y no tiene `ScaffoldMessenger` en su contexto. Un solo aviso por arranque (`_offlineNoticeShown`).
- Se descartó persistir el catálogo mapeado o precargar videos en el arranque: fuera de alcance de T04 y castiga el tiempo de inicio (invariante 4).

## Verificación

`dart format` sin cambios · `flutter analyze` → `No issues found!` · `flutter test` → **68/68** (`widget_test.dart` intacto). Avisos de proceso: el Operador agotó el tope de 16 pasos dos veces en T04b; se re-descompuso en T04b-1 (plumbing + test) y T04b-2 (3 lints) en vez de abrir GB.

## Pendiente

- **T05** (sensores reales + calibración + descarte de fixes) queda como siguiente tarea; no añade dependencias (`geolocator`, `flutter_compass` ya presentes).
- Validación en Android físico y capturas: G5 y T07.
- Sin commitear todo F1 desde T03b; el commit lo hace el humano en GC.
