import '../core/geo.dart';
import 'models.dart';

/// La API no publica altura; valor visual fijo.
const double defaultBuildingHeightM = 10;

/// Radio de cobertura por defecto cuando el payload no lo trae (invariante 2).
const double _defaultCoverageRadiusM = 20;

/// Mapea la respuesta real de `/sincronizar_v2` al catálogo local.
///
/// Función pura: sin Flutter, sin red y sin estado global. Las reglas aplicadas
/// son las de `docs/01-api-contract.md` §"Reglas de transformación (v2)":
/// - los accesos van primero, con el marcado `es_principal` al frente;
/// - el perímetro va después, como [CoordinateType.perimetro];
/// - un edificio sin coordenadas no entra al catálogo y suma a [Catalog.skipped].
Catalog catalogFromSincronizarV2(Map<String, dynamic> json) {
  if (json['success'] != true) {
    throw const FormatException('/sincronizar_v2: success distinto de true');
  }
  final rawBuildings = json['data'];
  if (rawBuildings is! List) {
    throw const FormatException('/sincronizar_v2: data no es una lista');
  }

  final drafts = <_BuildingDraft>[
    for (final raw in rawBuildings) _BuildingDraft.fromJson(_asMap(raw)),
  ];

  final points = <GeoPoint>[
    for (final draft in drafts)
      if (draft.coordinates.isNotEmpty)
        ...draft.coordinates.map((coordinate) => coordinate.point),
  ];
  final originLat = points.isEmpty
      ? null
      : points.fold<double>(0, (sum, point) => sum + point.lat) / points.length;
  final originLng = points.isEmpty
      ? null
      : points.fold<double>(0, (sum, point) => sum + point.lng) / points.length;

  final buildings = <Building>[];
  var skipped = 0;
  for (final draft in drafts) {
    if (draft.coordinates.isEmpty) {
      skipped++;
      continue;
    }
    buildings.add(draft.toBuilding(originLat!, originLng!));
  }

  final version = json['ultima_actualizacion'];
  return Catalog(
    version: version is String ? version : '',
    buildings: List<Building>.unmodifiable(buildings),
    originLat: originLat,
    originLng: originLng,
    skipped: skipped,
  );
}

class _BuildingDraft {
  _BuildingDraft({
    required this.id,
    required this.code,
    required this.name,
    required this.description,
    required this.dependencies,
    required this.tags,
    required this.category,
    required this.coverageRadiusM,
    required this.photoUrl,
    required this.videoUrl,
    required this.coordinates,
    required this.perimeter,
  });

  factory _BuildingDraft.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      throw const FormatException('/sincronizar_v2: edificio no es un objeto');
    }

    final principales = <BuildingCoordinate>[];
    final secundarias = <BuildingCoordinate>[];
    for (final raw in _asList(json['accesos'])) {
      final acceso = _asMap(raw);
      if (acceso == null) continue;
      final coordinate = BuildingCoordinate(
        type: CoordinateTypeX.parse(acceso['tipo_punto'] as String?),
        lat: (acceso['latitud'] as num).toDouble(),
        lng: (acceso['longitud'] as num).toDouble(),
      );
      if (acceso['es_principal'] == true) {
        principales.add(coordinate);
      } else {
        secundarias.add(coordinate);
      }
    }

    final perimeter = <GeoPoint>[];
    for (final raw in _asList(json['perimetro'])) {
      if (raw is! List || raw.length < 2) continue;
      final lat = raw[0];
      final lng = raw[1];
      if (lat is! num || lng is! num) continue;
      perimeter.add(GeoPoint(lat.toDouble(), lng.toDouble()));
    }

    return _BuildingDraft(
      id: _idToString(json['id']),
      code: _text(json['codigo']),
      name: _text(json['nombre']),
      description: _text(json['descripcion']),
      dependencies: _splitDependencies(json['dependencias']),
      tags: _stringList(json['etiquetas']),
      category: _categoryFromApi(json['categoria']),
      coverageRadiusM:
          (json['radio_cobertura'] as num?)?.toDouble() ??
          _defaultCoverageRadiusM,
      photoUrl: _optionalText(json['foto_url']),
      videoUrl: _optionalText(json['url_video']),
      coordinates: List<BuildingCoordinate>.unmodifiable([
        ...principales,
        ...secundarias,
        for (final point in perimeter)
          BuildingCoordinate(
            type: CoordinateType.perimetro,
            lat: point.lat,
            lng: point.lng,
          ),
      ]),
      perimeter: List<GeoPoint>.unmodifiable(perimeter),
    );
  }

  final String id;
  final String code;
  final String name;
  final String description;
  final List<String> dependencies;
  final List<String> tags;
  final BuildingCategory category;
  final double coverageRadiusM;
  final String? photoUrl;
  final String? videoUrl;
  final List<BuildingCoordinate> coordinates;
  final List<GeoPoint> perimeter;

  Building toBuilding(double originLat, double originLng) => Building(
    id: id,
    code: code,
    name: name,
    description: description,
    category: category,
    areaLabel: '',
    hours: '',
    coverageRadiusM: coverageRadiusM,
    dependencies: dependencies,
    tags: tags,
    photoAsset: null,
    videoAsset: null,
    photoUrl: photoUrl,
    videoUrl: videoUrl,
    footprint: _footprintFrom(perimeter, originLat, originLng),
    coordinates: coordinates,
  );
}

/// Bounding box del perímetro proyectada a metros locales respecto al origen
/// del catálogo. Con menos de 3 vértices no hay huella navegable.
MapFootprint? _footprintFrom(
  List<GeoPoint> perimeter,
  double originLat,
  double originLng,
) {
  if (perimeter.length < 3) return null;

  final metersPerDegLng = metersPerDegLngAt(originLat);
  var minEast = double.infinity;
  var maxEast = double.negativeInfinity;
  var minNorth = double.infinity;
  var maxNorth = double.negativeInfinity;
  for (final point in perimeter) {
    final east = (point.lng - originLng) * metersPerDegLng;
    final north = (point.lat - originLat) * metersPerDegLat;
    if (east < minEast) minEast = east;
    if (east > maxEast) maxEast = east;
    if (north < minNorth) minNorth = north;
    if (north > maxNorth) maxNorth = north;
  }

  return MapFootprint(
    east: minEast,
    north: minNorth,
    width: maxEast - minEast,
    depth: maxNorth - minNorth,
    height: defaultBuildingHeightM,
  );
}

Map<String, dynamic>? _asMap(Object? raw) =>
    raw is Map<String, dynamic> ? raw : null;

List<dynamic> _asList(Object? raw) => raw is List ? raw : const [];

String _text(Object? raw) => raw is String ? raw : '';

String? _optionalText(Object? raw) {
  if (raw is! String) return null;
  final trimmed = raw.trim();
  return trimmed.isEmpty ? null : trimmed;
}

String _idToString(Object? raw) {
  if (raw is int) return raw.toString();
  if (raw is num) {
    return raw == raw.roundToDouble() ? raw.toInt().toString() : raw.toString();
  }
  return raw is String ? raw : '';
}

/// `dependencias` llega como texto separado por comas.
List<String> _splitDependencies(Object? raw) {
  if (raw is! String) return const [];
  return List<String>.unmodifiable(
    raw.split(',').map((part) => part.trim()).where((part) => part.isNotEmpty),
  );
}

List<String> _stringList(Object? raw) => List<String>.unmodifiable(
  _asList(raw)
      .whereType<String>()
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty),
);

/// D-23: "Académico" → academico, "Administrativo" → administrativo, resto →
/// servicios. Se compara sin acentos ni mayúsculas por robustez.
BuildingCategory _categoryFromApi(Object? raw) {
  final name = _asMap(raw)?['nombre'];
  return switch (foldForSearch(name is String ? name : '')) {
    'academico' => BuildingCategory.academico,
    'administrativo' => BuildingCategory.administrativo,
    _ => BuildingCategory.servicios,
  };
}
