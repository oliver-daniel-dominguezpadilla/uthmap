# 03 — Arquitectura móvil (Flutter)

> **ESTRUCTURA REAL = la del prototipo** (ver `07-baseline-prototipo.md`: `lib/core/geo.dart`, `lib/core/geofence.dart`, `lib/state/navigation_controller.dart`, `lib/ui/...`). Lo de abajo describe los **puertos objetivo**; adaptar nombres al código existente. **Prohibido el refactor masivo (YAGNI)**: solo se introduce un puerto cuando una tarea lo necesita.

## Capas y límites
`UI (features)` → `domain (casos de uso, modelos)` → `data (API, almacenamiento)`; `core/geo` es puro y lo usa domain. Sensores detrás de interfaces para poder simularlos en tests. Sin dependencias circulares: UI nunca importa data directamente.

```
lib/
  core/geo/            geo_math.dart, heading_filter.dart, proximity_tracker.dart   (puro)
  domain/
    models/            building.dart, access_point.dart, category.dart
    ports/             catalog_repository.dart, position_source.dart, heading_source.dart, alert_service.dart
    usecases/          sync_catalog.dart, search_buildings.dart, track_proximity.dart, navigate_to.dart
  data/
    api/               campus_api.dart (http), dto/
    storage/           local_catalog_store.dart (clave-valor), image_cache.dart
    sensors/           gps_position_source.dart, compass_heading_source.dart
    alerts/            haptic_alert_service.dart
  features/
    welcome/  directory/  detail/  compass/  proximity/  map/ (extra)  video/ (extra)
  ui/theme/            tokens.dart, app_theme.dart
  main.dart
test/                  espejo de lib/
```

## Puertos (contratos internos)
```dart
abstract class CatalogRepository {
  Future<SyncOutcome> sync();                 // ultima_actualizacion → sincronizar_v2; nunca lanza por red
  Future<List<Building>> all();               // desde almacenamiento local
  Future<Building?> byId(int id);
}
abstract class PositionSource { Stream<GeoPoint> get positions; }   // fixes con accuracy <= 30 m
abstract class HeadingSource  { Stream<double> get headings; }      // grados 0..360, ya con declinación
abstract class AlertService   { Future<void> notifyProximity(); Future<void> notifyArrival(); }

enum SyncOutcome { updated, upToDate, offlineUsingLocal, rateLimited, failedUsingLocal }
```

## Modelos (campos mínimos)
`Building { id, codigo, nombre, descripcion, dependencias, radioCobertura, fotoUrl?, urlVideo?, categoria, etiquetas: List<String>, coordenadaCentral?, accesos: List<AccessPoint>, perimetro: List<GeoPoint> }`
`AccessPoint { id, nombre, punto: GeoPoint, tipo: ENTRADA_PRINCIPAL | ENTRADA_SECUNDARIA | PERIMETRO, esPrincipal }`

## Casos de uso
- **SearchBuildings:** filtro local en memoria; normaliza (minúsculas, sin acentos) y busca en nombre, código, dependencias y etiquetas. Debounce 150 ms. Sin red.
- **TrackProximity (Modo B):** por cada fix, para cada edificio calcula la distancia mínima a sus puntos (incluye `PERIMETRO`; sin Reto Mayor, solo accesos/central). Usa `ProximityTracker` con `radio_cobertura`. Emite eventos `entered(building)`.
- **NavigateTo (Modo A):** destino fijo; selecciona la entrada transitable más cercana (`nearestBy` sobre `accesos`, nunca `perimetro`); emite `{distanciaM, bearing, giro, etiquetaRelativa, llegado}` combinando `positions` + `headings` (heading ya filtrado). Llegada = `distancia <= min(15, radio)` → una sola vez.

## Decisiones técnicas (una línea cada una)
- Persistencia clave-valor JSON: el catálogo es pequeño y se filtra en memoria (KISS). Alternativa: sqflite si el catálogo crece a miles de registros.
- Imágenes: cachear en disco durante la sincronización para que la ficha funcione offline; si falla una imagen, mostrar placeholder tipográfico, no error.
- Permisos: ubicación mientras la app está en uso; manejo explícito de denegado/denegado permanente/servicio apagado, con pantalla de estado (no crash).
- Orientación de pantalla: bloqueo vertical.
- Estado: elegir UNA solución (recomendado: `flutter_riverpod` o `provider`, verificar versión vigente en pub.dev) y no mezclar.
- Paquetes candidatos (verificar existencia y versión en pub.dev antes de añadirlos): `http`, `geolocator`, `flutter_compass`, `shared_preferences`, `path_provider`, `cached_network_image`, `video_player`, `chewie`, `flutter_map`, `latlong2`. Háptica: `HapticFeedback` y `SystemSound` de `package:flutter/services.dart`.

## Observabilidad y calidad
- Logging estructurado local (nivel, evento, buildingId, distancia) con modo debug visible en ajustes: imprescindible para depurar en campo.
- Métricas manuales de campo: error de distancia (m) en 5 puntos conocidos, estabilidad de aguja (σ en reposo), latencia de aviso tras cruzar el radio.
- CI: `dart format --set-exit-if-changed`, `flutter analyze`, `flutter test`.

## Android primero (iOS secundario)
- Probar sensores en **dispositivo físico**: los emuladores simulan mal el magnetómetro y el GPS continuo.
- `AndroidManifest.xml`: permisos de ubicación fina/aproximada e `INTERNET`. Verificar en la documentación del plugin de ubicación elegido si requiere algo más.
- **Tráfico HTTP:** los ejemplos del manual usan `http://`. Android 9+ bloquea tráfico en claro por defecto; si la `BASE_URL` real es HTTP, hace falta habilitar `usesCleartextTraffic` para ese host (preferible HTTPS). Confirmar la `BASE_URL` real antes de T03.
- No escribir código ni configuración iOS-específica hasta que se priorice iOS (Info.plist, permisos, entitlements quedan pendientes).
- Ahorro de batería: suscribirse al GPS solo con la pantalla de brújula/proximidad activa y cancelar el stream al pausar la app.
