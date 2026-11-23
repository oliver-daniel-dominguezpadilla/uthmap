import 'dart:math' as math;

/// Radio medio terrestre exigido por el enunciado (Nota 3).
const double earthRadiusM = 6371000;

/// Origen del campus simulado. Todas las distancias locales se proyectan
/// respecto a este punto con la misma aproximación que usa el wireframe.
const double campusOriginLat = 19.0;
const double campusOriginLng = -98.2;

const double metersPerDegLat = 111320;

double toRadians(double degrees) => degrees * math.pi / 180;

double toDegrees(double radians) => radians * 180 / math.pi;

/// Normaliza a [0, 360). El módulo de Dart puede devolver negativos.
double normalizeDegrees(double value) => ((value % 360) + 360) % 360;

/// Distancia geodésica en línea recta sobre la esfera terrestre.
double haversineM(double lat1, double lon1, double lat2, double lon2) {
  final phi1 = toRadians(lat1);
  final phi2 = toRadians(lat2);
  final deltaPhi = toRadians(lat2 - lat1);
  final deltaLambda = toRadians(lon2 - lon1);
  final a =
      math.pow(math.sin(deltaPhi / 2), 2) +
      math.cos(phi1) * math.cos(phi2) * math.pow(math.sin(deltaLambda / 2), 2);
  return 2 * earthRadiusM * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

/// Rumbo inicial (azimut geodésico) de un punto a otro, en [0, 360).
double initialBearingDeg(double lat1, double lon1, double lat2, double lon2) {
  final phi1 = toRadians(lat1);
  final phi2 = toRadians(lat2);
  final deltaLambda = toRadians(lon2 - lon1);
  final y = math.sin(deltaLambda) * math.cos(phi2);
  final x =
      math.cos(phi1) * math.sin(phi2) -
      math.sin(phi1) * math.cos(phi2) * math.cos(deltaLambda);
  return normalizeDegrees(toDegrees(math.atan2(y, x)));
}

/// Ángulo de giro visual de la aguja (Nota 5).
double needleAngleDeg(double bearingDeg, double headingDeg) =>
    normalizeDegrees(bearingDeg - headingDeg);

/// Diferencia angular más corta, en (-180, 180].
double shortestDeltaDeg(double fromDeg, double toDeg) {
  final delta = normalizeDegrees(toDeg - fromDeg);
  return delta > 180 ? delta - 360 : delta;
}

/// Etiqueta de cuadrante del Reto Mayor.
String quadrantLabel(double needleDeg) {
  final angle = normalizeDegrees(needleDeg);
  if (angle >= 315 || angle < 45) return 'Al frente';
  if (angle < 135) return 'A tu derecha';
  if (angle < 225) return 'A tus espaldas';
  return 'A tu izquierda';
}

/// Frase accionable que usa el panel inferior del wireframe.
String quadrantHint(double needleDeg) {
  final angle = normalizeDegrees(needleDeg);
  if (angle >= 315 || angle < 45) return 'Al frente, sigue recto';
  if (angle < 135) return 'A tu derecha, gira a la derecha';
  if (angle < 225) {
    return angle < 180
        ? 'A tus espaldas, gira a la derecha'
        : 'A tus espaldas, gira a la izquierda';
  }
  return 'A tu izquierda, gira a la izquierda';
}

double metersPerDegLngAt(double lat) =>
    metersPerDegLat * math.cos(toRadians(lat));

class GeoPoint {
  const GeoPoint(this.lat, this.lng);

  final double lat;
  final double lng;

  @override
  String toString() => 'GeoPoint($lat, $lng)';
}

class LocalMeters {
  const LocalMeters(this.east, this.north);

  final double east;
  final double north;
}

class NearestPoint {
  const NearestPoint(this.point, this.distanceM);

  final GeoPoint point;
  final double distanceM;
}

/// Proyecta [point] a metros locales respecto a [origin]. Por defecto usa el
/// origen global del campus, pero el catálogo puede traer su propio centro
/// (D-26): el mapa y los datos deben compartir el mismo origen.
LocalMeters projectToCampus(
  GeoPoint point, {
  GeoPoint origin = const GeoPoint(campusOriginLat, campusOriginLng),
}) => LocalMeters(
  (point.lng - origin.lng) * metersPerDegLngAt(origin.lat),
  (point.lat - origin.lat) * metersPerDegLat,
);

/// Inverso de [projectToCampus] para el mismo [origin].
GeoPoint campusPoint(
  double east,
  double north, {
  GeoPoint origin = const GeoPoint(campusOriginLat, campusOriginLng),
}) => GeoPoint(
  origin.lat + north / metersPerDegLat,
  origin.lng + east / metersPerDegLngAt(origin.lat),
);

GeoPoint moveBy(GeoPoint from, double bearingDeg, double distanceM) => GeoPoint(
  from.lat + distanceM * math.cos(toRadians(bearingDeg)) / metersPerDegLat,
  from.lng +
      distanceM * math.sin(toRadians(bearingDeg)) / metersPerDegLngAt(from.lat),
);

/// Punto más cercano de una colección (modo B y accesos del modo A).
NearestPoint? nearestOf(GeoPoint from, Iterable<GeoPoint> points) {
  NearestPoint? best;
  for (final point in points) {
    final distance = haversineM(from.lat, from.lng, point.lat, point.lng);
    if (best == null || distance < best.distanceM) {
      best = NearestPoint(point, distance);
    }
  }
  return best;
}

/// Filtro pasa-bajas de primer orden para el magnetómetro.
/// y += alpha * shortestDelta(x, y), resolviendo el paso 359 -> 0.
class LowPassAngle {
  LowPassAngle(this.alpha, [double? initial]) : _value = initial;

  final double alpha;
  double? _value;

  bool get hasValue => _value != null;

  double get value => _value ?? 0;

  double filter(double sample) {
    final current = _value;
    if (current == null) {
      _value = normalizeDegrees(sample);
      return _value!;
    }
    _value = normalizeDegrees(
      current + alpha * shortestDeltaDeg(current, sample),
    );
    return _value!;
  }

  void reset(double value) => _value = normalizeDegrees(value);
}
