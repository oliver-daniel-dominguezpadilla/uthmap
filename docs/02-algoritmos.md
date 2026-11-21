# 02 — Algoritmos geodésicos (referencia + tests)

> El prototipo ya tiene `lib/core/geo.dart` y `lib/core/geofence.dart` con estas funciones. Esta referencia sirve para **auditar** el código existente contra los vectores y completar tests faltantes; no duplicar módulos. Paquete real: `uthmap` (sustituir `campus_compass` en los imports de test).

Funciones puras (en el prototipo: `lib/core/`), sin Flutter ni sensores. Los vectores de prueba fueron calculados con Python (`math`, R = 6 371 000 m). El código Dart de abajo es referencia: **no fue ejecutado al redactar este documento**; el operador debe correr los tests.

## Fórmulas
- **Haversine:** `a = sin²(Δφ/2) + cos φ1 · cos φ2 · sin²(Δλ/2)`; `d = 2R · asin(√a)`.
- **Bearing inicial:** `y = sin Δλ · cos φ2`; `x = cos φ1 · sin φ2 − sin φ1 · cos φ2 · cos Δλ`; `θ = atan2(y, x)`; `rumbo = (θ·180/π + 360) mod 360`.
- **Aguja:** `giro = (bearing − heading) mod 360`. Rotar el SVG `giro` grados en sentido horario (0° = arriba).
- **Cuadrantes (texto relativo), sobre `giro`, intervalos semiabiertos:**
  - `[315, 360) ∪ [0, 45)` → "Al frente"
  - `[45, 135)` → "A tu derecha"
  - `[135, 225)` → "A tus espaldas"
  - `[225, 315)` → "A tu izquierda"
- **Pasa-bajas con cruce de norte:** `Δ = ((raw − prev + 540) mod 360) − 180`; `suave = (prev + α·Δ) mod 360`; α ∈ [0.10, 0.20] (recomendado 0.15). Inicializar `prev` con la primera lectura.

## Referencia Dart
```dart
// lib/core/geo/geo_math.dart
import 'dart:math' as math;

const double earthRadiusM = 6371000.0;

class GeoPoint {
  const GeoPoint(this.lat, this.lon);
  final double lat;
  final double lon;
}

double _rad(double d) => d * math.pi / 180.0;
double _deg(double r) => r * 180.0 / math.pi;

double normalize360(double deg) => ((deg % 360) + 360) % 360;

double haversineM(GeoPoint a, GeoPoint b) {
  final p1 = _rad(a.lat), p2 = _rad(b.lat);
  final dp = p2 - p1, dl = _rad(b.lon - a.lon);
  final sdp = math.sin(dp / 2), sdl = math.sin(dl / 2);
  final h = sdp * sdp + math.cos(p1) * math.cos(p2) * sdl * sdl;
  return 2 * earthRadiusM * math.asin(math.sqrt(h.clamp(0.0, 1.0)));
}

double initialBearingDeg(GeoPoint from, GeoPoint to) {
  final p1 = _rad(from.lat), p2 = _rad(to.lat);
  final dl = _rad(to.lon - from.lon);
  final y = math.sin(dl) * math.cos(p2);
  final x = math.cos(p1) * math.sin(p2) - math.sin(p1) * math.cos(p2) * math.cos(dl);
  return normalize360(_deg(math.atan2(y, x)));
}

double needleAngleDeg({required double bearing, required double heading}) =>
    normalize360(bearing - heading);

String relativeLabel(double needleAngle) {
  final a = normalize360(needleAngle);
  if (a >= 315 || a < 45) return 'Al frente';
  if (a < 135) return 'A tu derecha';
  if (a < 225) return 'A tus espaldas';
  return 'A tu izquierda';
}

T? nearestBy<T>(GeoPoint user, Iterable<T> items, GeoPoint Function(T) pos) {
  T? best;
  var bestD = double.infinity;
  for (final it in items) {
    final d = haversineM(user, pos(it));
    if (d < bestD) { bestD = d; best = it; }
  }
  return best;
}
```
```dart
// lib/core/geo/heading_filter.dart
import 'geo_math.dart';

class HeadingFilter {
  HeadingFilter({this.alpha = 0.15}) : assert(alpha > 0 && alpha <= 1);
  final double alpha;
  double? _prev;

  double next(double raw) {
    final r = normalize360(raw);
    final p = _prev;
    if (p == null) return _prev = r;
    final delta = ((r - p + 540) % 360) - 180;
    return _prev = normalize360(p + alpha * delta);
  }

  void reset() => _prev = null;
}
```
```dart
// lib/core/geo/proximity_tracker.dart
/// Devuelve true solo en la transición fuera→dentro. Rearma al superar radio + histéresis.
class ProximityTracker {
  ProximityTracker({this.hysteresisM = 5});
  final double hysteresisM;
  final Set<int> _inside = {};

  bool update({required int buildingId, required double distanceM, required double radiusM}) {
    final inside = _inside.contains(buildingId);
    if (!inside && distanceM <= radiusM) {
      _inside.add(buildingId);
      return true;
    }
    if (inside && distanceM > radiusM + hysteresisM) _inside.remove(buildingId);
    return false;
  }
}
```

## Tests (con vectores verificados)
Punto base A = (20.08123456, −98.76123456).

| Caso | Destino | Distancia esperada | Bearing esperado |
|---|---|---|---|
| Ecuador 1° lon | (0,0)→(0,1) | 111 194.927 m | 90.0 |
| Meridiano 1° lat | (0,0)→(1,0) | 111 194.927 m | 0.0 |
| 100 m al norte | A→(20.08213388, −98.76123456) | 99.9998 m | 0.0 |
| 100 m al este | A→(20.08123456, −98.76027703) | 99.9997 m | 89.9998 |
| Noroeste | A→(20.08134567, −98.76134567) | 16.9496 m | 316.7956 |
| Mismo punto | A→A | 0.0 | (no afirmar) |

```dart
// test/core/geo/geo_math_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:campus_compass/core/geo/geo_math.dart';
import 'package:campus_compass/core/geo/heading_filter.dart';
import 'package:campus_compass/core/geo/proximity_tracker.dart';

void main() {
  const a = GeoPoint(20.08123456, -98.76123456);

  test('haversine ecuador y meridiano', () {
    expect(haversineM(const GeoPoint(0, 0), const GeoPoint(0, 1)), closeTo(111194.927, 0.01));
    expect(haversineM(const GeoPoint(0, 0), const GeoPoint(1, 0)), closeTo(111194.927, 0.01));
  });

  test('haversine y bearing: norte, este, noroeste', () {
    const n = GeoPoint(20.08213388, -98.76123456);
    const e = GeoPoint(20.08123456, -98.76027703);
    const nw = GeoPoint(20.08134567, -98.76134567);
    expect(haversineM(a, n), closeTo(99.9998, 0.01));
    expect(initialBearingDeg(a, n), closeTo(0.0, 0.01));
    expect(haversineM(a, e), closeTo(99.9997, 0.01));
    expect(initialBearingDeg(a, e), closeTo(89.9998, 0.01));
    expect(haversineM(a, nw), closeTo(16.9496, 0.01));
    expect(initialBearingDeg(a, nw), closeTo(316.7956, 0.01));
  });

  test('haversine mismo punto = 0', () => expect(haversineM(a, a), 0.0));

  test('aguja usa módulo 360', () {
    expect(needleAngleDeg(bearing: 10, heading: 350), closeTo(20, 1e-9));
    expect(needleAngleDeg(bearing: 350, heading: 10), closeTo(340, 1e-9));
    expect(needleAngleDeg(bearing: 90, heading: 90), 0);
  });

  test('cuadrantes y bordes semiabiertos', () {
    expect(relativeLabel(0), 'Al frente');
    expect(relativeLabel(44.99), 'Al frente');
    expect(relativeLabel(45), 'A tu derecha');
    expect(relativeLabel(135), 'A tus espaldas');
    expect(relativeLabel(225), 'A tu izquierda');
    expect(relativeLabel(315), 'Al frente');
    expect(relativeLabel(359.9), 'Al frente');
  });

  test('filtro pasa-bajas cruza el norte por el camino corto', () {
    final f = HeadingFilter(alpha: 0.15);
    f.next(359);
    expect(f.next(1), closeTo(359.3, 1e-9));
    final g = HeadingFilter(alpha: 0.15);
    g.next(1);
    expect(g.next(359), closeTo(0.7, 1e-9));
    final h = HeadingFilter(alpha: 0.2);
    h.next(10);
    expect(h.next(20), closeTo(12.0, 1e-9));
  });

  test('geocerca: dispara una vez, histéresis y rearme', () {
    final t = ProximityTracker(hysteresisM: 5);
    expect(t.update(buildingId: 1, distanceM: 25, radiusM: 20), false);
    expect(t.update(buildingId: 1, distanceM: 19, radiusM: 20), true);
    expect(t.update(buildingId: 1, distanceM: 18, radiusM: 20), false);
    expect(t.update(buildingId: 1, distanceM: 23, radiusM: 20), false); // dentro de histéresis
    expect(t.update(buildingId: 1, distanceM: 26, radiusM: 20), false); // sale y rearma
    expect(t.update(buildingId: 1, distanceM: 19, radiusM: 20), true);
  });
}
```
Nombre de paquete `campus_compass` asumido; ajustar al `pubspec.yaml` real.

## Riesgos de sensores
- **Declinación magnética:** el heading del magnetómetro es respecto al norte magnético; el bearing, al geográfico. En la zona (~20°N, −98.7°) la diferencia es de unos pocos grados (no verificado; medir en campo). Mitigación: constante configurable `declinationDeg` sumada al heading.
- **Precisión GPS 5–15 m en exteriores:** por eso la histéresis y el umbral de 15–20 m. Ignorar fixes con `accuracy` > 30 m para disparar eventos.
- **Calibración del magnetómetro:** mostrar aviso discreto si la precisión del sensor es baja (si el plugin la expone; verificar).
