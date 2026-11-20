# UniCompass: Documento de Arquitectura v0.1

Sistema de navegación por rumbo, geocercado perimetral y guía universitaria. Estado: propuesta para aprobación. Alcance: decisiones técnicas previas a implementar.

## 1. Resumen ejecutivo

- Móvil en **Flutter/Dart**; backend en **Django + Django REST Framework + PostgreSQL**.
- Toda la lógica de navegación vive en un módulo Dart puro (`core/`), sin dependencias de Flutter ni de sensores. Se prueba con tests unitarios.
- La app sincroniza el catálogo una vez, lo guarda en SQLite local y opera offline (Notas 1 y 2 del enunciado).
- El modelo de datos nace con coordenadas 1:N, para no migrar después al Reto Mayor.
- Sin SDK cartográfico de pago. El mapa opcional usa OpenStreetMap.

## 2. Supuestos

1. Un equipo pequeño; una persona puede tocar backend y móvil.
2. El enunciado menciona `video_player`/`chewie`, así que Flutter es el cliente esperado.
3. Evaluación en dispositivo físico Android (iOS opcional).
4. Despliegue del backend en un VPS o PaaS barato; la evaluación puede usar red local o túnel.
5. Volumen: decenas a cientos de edificios; sin requisitos de escala.

## 3. Decisiones tecnológicas

| Área | Decisión | Justificación (1 línea) | Alternativa |
|---|---|---|---|
| Lenguaje móvil | Dart 3 | Requerido por Flutter; null-safety y tipos sellados para modelar estados | Kotlin (solo Android) |
| Framework móvil | Flutter 3.x | Un código, acceso a GPS y magnetómetro, `CustomPainter` para la brújula | React Native |
| Estado | Riverpod | Inyección de dependencias testeable, sin `BuildContext` en la lógica | Bloc |
| Sensores | `geolocator` (GPS), `flutter_compass` (rumbo) | Paquetes mantenidos y comunes; abstraídos tras interfaces | `sensors_plus` (magnetómetro crudo) |
| Persistencia local | SQLite vía `drift` | Consultas para búsqueda por texto y etiquetas, esquema tipado | `sqflite`, Hive |
| HTTP | `dio` | Interceptores, timeouts, reintentos | `http` |
| Imágenes offline | Descarga a disco en sync (`path_provider`) | La ficha debe mostrar foto sin Internet; una caché en memoria no lo garantiza | `cached_network_image` |
| Alerta | `vibration` + `audioplayers` | Aviso háptico y sonoro | `HapticFeedback` nativo |
| Video (extra) | `video_player` + `chewie` | Los nombra el enunciado | |
| Mapa (extra) | `flutter_map` + tiles OSM | Sin credenciales ni costo | |
| Backend | Django 5 + DRF | El enunciado lo sugiere (Django/FileField); admin incluido | FastAPI |
| Panel admin | Django Admin personalizado | Login seguro, CRUD e inlines sin construir un front web | SPA propia (más costo, sin ganancia en nota) |
| Base de datos | PostgreSQL (SQLite en desarrollo) | Integridad relacional para 1:N | MySQL |
| Auth admin | Sesión de Django; la API de lectura es pública | El catálogo no es sensible; las escrituras solo vía panel | Token JWT para la API |
| Archivos | `MEDIA_ROOT` servido por Nginx | Simple; migrable a S3 | Almacenamiento de objetos |
| Despliegue | Docker Compose: Django (gunicorn), Postgres, Nginx | Reproducible | Un PaaS |
| CI | GitHub Actions | Tests de `core/` y backend en cada push | |

Verificar versiones exactas de paquetes en pub.dev al iniciar el proyecto; esta tabla fija elección, no versión.

## 4. Arquitectura

### 4.1 Componentes y límites

```
[Admin web (Django Admin)] --> [Django + DRF] --> [PostgreSQL]
                                     |                [MEDIA: fotos, videos]
                                     v  JSON (solo en sync)
[App Flutter]
  ui/        pantallas, widgets, tema (consume NavState)
  app/       providers Riverpod, casos de uso (SyncCatalog, StartNavigation)
  core/      Dart puro: haversine, bearing, filtros, geocerca
  sensors/   interfaces PositionSource, HeadingSource + implementaciones real/fake
  data/      repositorio, drift (SQLite), cliente dio, almacén de archivos
```

Regla de dependencia: `ui → app → core`, `app → sensors`, `app → data`. `core/` no importa a nadie. Sin ciclos.

### 4.2 Flujo de datos en ejecución

1. Arranque: si hay red, `SyncCatalog` pide `GET /api/v1/edificios/` (con `If-None-Match`). Aplica cambios en SQLite en una transacción y descarga fotos y videos pendientes. Si no hay red, usa lo local.
2. `PositionSource` emite posiciones (~1 Hz). `HeadingSource` emite rumbo (~10-20 Hz) con filtro pasa-bajas.
3. `NavEngine` combina ambos flujos y publica un `NavState` inmutable.
4. La UI solo observa `NavState`. Nunca llama a sensores.

### 4.3 Contrato de estado (frontera motor/UI)

```dart
enum NavMode { explore, directed }          // B, A
enum SensorStatus { ok, denied, disabled, noSignal, uncalibrated }

class NavState {
  final NavMode mode;
  final double? distanceM;        // al destino (A) o al punto más cercano (B)
  final double? needleDeg;        // (bearing - heading) mod 360, ya filtrado
  final double? bearingDeg;       // azimut absoluto
  final double? headingDeg;       // orientación del teléfono, filtrada
  final String? quadrant;         // Al frente | A tu derecha | A tus espaldas | A tu izquierda
  final Building? target;         // modo A
  final Building? nearby;         // modo B: geocerca activa
  final bool arrived;             // distancia <= 15 m
  final SensorStatus gps;
  final SensorStatus compass;
}
```

## 5. Modelo de datos (backend)

Decisión: separar coordenadas desde el inicio (relación 1:N). Un solo punto se modela como una fila `ENTRADA_PRINCIPAL`; el Reto Mayor no exige migración.

| Entidad | Campos clave |
|---|---|
| `Categoria` | id, nombre (Académico, Administrativo, Servicios) |
| `Edificio` | id, codigo (único), nombre, descripcion, dependencias (texto), horarios, categoria FK, foto (ImageField), url_video (nullable), radio_cobertura_m (default 20), etiquetas (M2M o texto), activo, actualizado_en |
| `Etiqueta` | id, nombre (servicios, trámites, carreras) |
| `EdificioCoordenadaGps` | id, edificio FK, tipo (`ENTRADA_PRINCIPAL` \| `ENTRADA_SECUNDARIA` \| `PERIMETRO`), latitud, longitud, orden |

Restricciones: latitud en [-90, 90], longitud en [-180, 180]; cada edificio activo con al menos una `ENTRADA_PRINCIPAL`; radio entre 5 y 100 m; `codigo` único.

## 6. Contrato de API

Solo lectura para la app. Versionada en ruta.

`GET /api/v1/edificios/` responde 200 con `ETag`, o 304 si no hay cambios.

```json
{
  "version": "2026-11-06T18:00:00Z",
  "edificios": [{
    "id": 11,
    "codigo": "K",
    "nombre": "Edificio K",
    "descripcion": "...",
    "dependencias": ["Servicios Escolares"],
    "categoria": "ADMINISTRATIVO",
    "horarios": "Lun-Vie 8:00-15:00",
    "radio_cobertura_m": 20,
    "etiquetas": ["inscripciones", "constancias"],
    "foto_url": "https://dominio/media/fachadas/k.jpg",
    "url_video": null,
    "coordenadas": [
      {"tipo": "ENTRADA_PRINCIPAL", "lat": 19.43210, "lng": -99.13320},
      {"tipo": "PERIMETRO", "lat": 19.43225, "lng": -99.13341}
    ]
  }]
}
```

Errores: 304 sin cambios, 5xx con cuerpo `{"error": "codigo", "detalle": "..."}`. Las URLs son absolutas. Los campos opcionales se serializan como `null`, nunca se omiten.

## 7. Diseño detallado del motor (`core/`)

Todas son funciones puras con grados como entrada y salida.

| Función | Definición | Nota |
|---|---|---|
| `haversine(lat1, lon1, lat2, lon2)` | Radio 6,371,000 m, entrada en radianes internamente | Obligatoria (Nota 3) |
| `initialBearing(lat1, lon1, lat2, lon2)` | `atan2(sin Δλ·cos φ2, cos φ1·sin φ2 − sin φ1·cos φ2·cos Δλ)`, normalizado a [0, 360) | Obligatoria (Nota 4) |
| `needleAngle(bearing, heading)` | `(bearing − heading) mod 360` con módulo no negativo | Nota 5 |
| `quadrantLabel(needleDeg)` | [315,45) al frente; [45,135) derecha; [135,225) espaldas; [225,315) izquierda | Bordes: inferior inclusivo, superior exclusivo |
| `LowPassAngle(alpha)` | `y += alpha · shortestDelta(x, y)`, delta en (−180, 180]; alpha 0.15 | Resuelve el paso 359° a 0° |
| `GeofenceEvaluator` | Entra a ≤ `radio` (15-20 m); sale a > `radio + 5` | Histéresis: evita parpadeo por jitter de GPS |
| `nearestEntrance(pos, coords)` | Modo A: filtra `PERIMETRO`, elige la entrada más cercana | Reto Mayor |
| `nearestAnyPoint(pos, coords)` | Modo B: considera todos los puntos | Reto Mayor |

### Reglas de la máquina de estados

- Modo B (por defecto): evalúa todos los edificios; al entrar a una geocerca, `nearby` se fija y se dispara un solo aviso (vibración + sonido corta) hasta salir con histéresis.
- Modo A: se activa al elegir destino. Aguja y metros restantes hasta ≤ 15 m; entonces `arrived = true`, alerta, y la UI abre la ficha completa. El enunciado menciona 20 m para "en ruta" y 15 m para llegada; se resuelve así: la brújula sigue activa hasta 15 m.
- Posición con `accuracy` peor que 30 m: `gps = noSignal`, la geocerca no dispara. Supuesto propio, ajustable tras pruebas de campo.
- Cambio de modo: elegir destino pasa a A; cancelar vuelve a B.

### Manejo de errores

| Caso | Comportamiento |
|---|---|
| Permiso de ubicación denegado | `gps = denied`; pantalla de recuperación con acceso a ajustes; directorio sigue funcionando |
| GPS desactivado | `gps = disabled`; aviso accionable |
| Sin magnetómetro o descalibrado | `compass = uncalibrated`; mostrar distancia y rumbo numérico, y aviso de calibrar (figura en 8) |
| Sin red en primer arranque | Pantalla de bienvenida con reintento; sin catálogo no hay navegación |
| Falla la descarga de una imagen | Se guarda el registro; la imagen se reintenta en el siguiente sync; placeholder neutro |
| Video sin conectividad | Estado de error con reintento en el reproductor |

## 8. Diseño UI/UX (tokens, para la fase de prototipo)

- Superficies: fondo `#0A0A0A`, tarjetas `#161616`, acento `#CCFF00`. Sin degradados ni brillos.
- Tipografía: sin Inter. Un display geométrico o neo-grotesco para cifras y un cuerpo sobrio; máximo 3 pesos. Elegir y fijar en el prototipo.
- El elemento dominante es la cifra de metros restantes; la aguja es SVG/`CustomPainter`.
- Radios: tarjetas `rounded-xl`, controles `rounded-md`. Íconos lineales 24x24, stroke 2, un solo set.
- Movimiento: 150 ms ease-out, respeta `prefers-reduced-motion` (en Flutter: `MediaQuery.disableAnimations`).
- Contraste mínimo 4.5:1; el color no es el único indicador de estado.
- El prototipo HTML valida diseño. La implementación real se hace en Flutter y migra los tokens a `ThemeData`.

## 9. Seguridad, rendimiento, observabilidad y costo

- **Seguridad:** HTTPS obligatorio; `DEBUG=False` y `SECRET_KEY` por variable de entorno; admin con contraseña fuerte y limitación de intentos; validación de tipo y tamaño de archivos subidos (imagen ≤ 5 MB, video MP4 ≤ 50 MB); sin API de escritura pública; permisos de ubicación pedidos en contexto y solo en uso.
- **Privacidad:** la posición del usuario nunca sale del dispositivo (cálculo local). Se documenta en la pantalla de permisos.
- **Rendimiento:** respuesta de sync < 2 s con 200 edificios; fotos servidas redimensionadas (≤ 1280 px); la UI de brújula a 60 fps con rumbo filtrado; costo de batería controlado con GPS a ~1 Hz y `distanceFilter` de 2-3 m.
- **Observabilidad:** logs estructurados en backend; en móvil un log local con eventos de geocerca y precisión del GPS para diagnosticar pruebas de campo. Sin analítica de terceros.
- **Costo:** VPS pequeño o nivel gratuito; sin licencias cartográficas.

## 10. Estructura del repositorio

```
unicompass/
  backend/        Django (apps: catalogo, api), Dockerfile, tests
  mobile/         Flutter (lib/core, lib/sensors, lib/data, lib/app, lib/ui)
  docs/           este documento, ADRs, contrato OpenAPI
  .github/workflows/
  docker-compose.yml
```

## 11. Plan de ejecución

| Fase | Entregable | Depende de | Paralelizable con |
|---|---|---|---|
| 0 | Este documento aprobado, contrato `NavState`, contrato API (OpenAPI) | Ninguna | |
| 1 | Backend: modelos, admin, serializador, endpoint, seed con 5 edificios | 0 | 1b, 1c |
| 1b | `core/` con tests (haversine, bearing, ángulo, cuadrantes, filtro, geocerca) | 0 | 1, 1c |
| 1c | Prototipo visual (HTML) del diseño | 0 | 1, 1b |
| 2 | App nivel 7.0: bienvenida, directorio, detalle, sync, SQLite, offline | 1 | 1b |
| 3 | Nivel 8.0: Modo B con GPS real, geocerca, alerta, foto en tarjeta | 1b, 2 | |
| 4 | Nivel 9.0: búsqueda, brújula con magnetómetro, llegada | 3 | |
| 5 | Reto Mayor (multi-punto + cuadrantes) y filtro pasa-bajas | 4 | |
| 6 | Pruebas de campo y ajuste de umbrales | 5 | |
| 7 | Extras restantes: video, mapa OSM | 6 | entre sí |

Orden de extras por retorno: Reto Mayor (+10), filtro pasa-bajas (+3), luego video o mapa (+3 cada uno).

## 12. Riesgos y mitigaciones

| Riesgo | Impacto | Mitigación |
|---|---|---|
| Magnetómetro ruidoso | Aguja inestable | Filtro α 0.10-0.20 y aviso de calibración |
| GPS impreciso en el campus | Falsos o ausentes avisos | Umbral 15-20 m, histéresis, filtro por `accuracy` |
| Evaluación sin red | Falla de sync | Caché persistente, prueba en modo avión |
| Coordenadas de acceso mal capturadas | Rumbo erróneo | Validar en campo con el dispositivo; recoger puntos en la puerta |
| Permisos denegados | App inútil | Estados explícitos y pantalla de recuperación |
| Cambiar a 1:N tarde | Retrabajo | Modelo 1:N desde la Fase 1 |
| Dependencia de paquetes de sensores | Bloqueo | Interfaces + `FakeSource`; reemplazo local |

## 13. Definition of Done

- `core/` con cobertura ≥ 90 % y sin importar Flutter.
- Tests de caso conocido: haversine mismo punto = 0 m y 1° de latitud ≈ 111.19 km; bearing a N/E/S/O = 0/90/180/270°; `needleAngle(10, 350)` = 20°; filtro 359° a 1° sin pasar por 180°; bordes de cuadrante fijados en test.
- App 100 % funcional offline tras la primera sincronización, incluidas fotos.
- Pruebas de campo: aviso a ≤ 20 m en 3 de 3 edificios; aguja estable (±10°) caminando; llegada a ≤ 15 m.
- UI renderiza todos los valores de `SensorStatus`.
- CI verde: tests de `core/` y backend, análisis estático (`flutter analyze`, linter de Python).
- API validada contra el contrato OpenAPI; `url_video` y campos opcionales siempre presentes.

## 14. Preguntas abiertas

1. ¿Plataforma de evaluación: solo Android o también iOS?
2. ¿Dónde se hospeda el backend durante la evaluación (VPS, red local, túnel)?
3. ¿Hay restricción de framework en la materia fuera del documento (por ejemplo, Flutter obligatorio)?

Supuestos aplicados mientras tanto: Android, VPS con Docker, Flutter.
