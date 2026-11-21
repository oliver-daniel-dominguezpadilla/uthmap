import '../core/geo.dart';

enum BuildingCategory { academico, administrativo, servicios }

extension BuildingCategoryX on BuildingCategory {
  String get label => switch (this) {
    BuildingCategory.academico => 'Académico',
    BuildingCategory.administrativo => 'Administrativo',
    BuildingCategory.servicios => 'Servicios',
  };

  static BuildingCategory parse(String? raw) => switch (raw) {
    'administrativo' => BuildingCategory.administrativo,
    'servicios' => BuildingCategory.servicios,
    _ => BuildingCategory.academico,
  };
}

enum CoordinateType { entradaPrincipal, entradaSecundaria, perimetro }

extension CoordinateTypeX on CoordinateType {
  bool get isEntrance => this != CoordinateType.perimetro;

  static CoordinateType parse(String? raw) => switch (raw) {
    'ENTRADA_SECUNDARIA' => CoordinateType.entradaSecundaria,
    'PERIMETRO' => CoordinateType.perimetro,
    _ => CoordinateType.entradaPrincipal,
  };
}

class BuildingCoordinate {
  const BuildingCoordinate({
    required this.type,
    required this.lat,
    required this.lng,
  });

  factory BuildingCoordinate.fromJson(Map<String, dynamic> json) =>
      BuildingCoordinate(
        type: CoordinateTypeX.parse(json['tipo'] as String?),
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
      );

  final CoordinateType type;
  final double lat;
  final double lng;

  GeoPoint get point => GeoPoint(lat, lng);
}

class MapFootprint {
  const MapFootprint({
    required this.east,
    required this.north,
    required this.width,
    required this.depth,
    required this.height,
  });

  factory MapFootprint.fromJson(Map<String, dynamic> json) => MapFootprint(
    east: (json['este'] as num).toDouble(),
    north: (json['norte'] as num).toDouble(),
    width: (json['ancho'] as num).toDouble(),
    depth: (json['fondo'] as num).toDouble(),
    height: (json['alto'] as num).toDouble(),
  );

  final double east;
  final double north;
  final double width;
  final double depth;
  final double height;
}

class Building {
  const Building({
    required this.id,
    required this.code,
    required this.name,
    required this.description,
    required this.category,
    required this.areaLabel,
    required this.hours,
    required this.coverageRadiusM,
    required this.dependencies,
    required this.tags,
    required this.photoAsset,
    required this.videoAsset,
    this.footprint,
    this.photoUrl,
    this.videoUrl,
    required this.coordinates,
  });

  factory Building.fromJson(Map<String, dynamic> json) => Building(
    id: json['id'] as String,
    code: json['codigo'] as String,
    name: json['nombre'] as String,
    description: json['descripcion'] as String,
    category: BuildingCategoryX.parse(json['categoria'] as String?),
    areaLabel: json['area'] as String? ?? '',
    hours: json['horarios'] as String? ?? '',
    coverageRadiusM: (json['radio_cobertura_m'] as num?)?.toDouble() ?? 20,
    dependencies: List<String>.from(json['dependencias'] as List? ?? const []),
    tags: List<String>.from(json['etiquetas'] as List? ?? const []),
    photoAsset: json['foto'] as String?,
    videoAsset: json['video'] as String?,
    footprint: MapFootprint.fromJson(json['mapa'] as Map<String, dynamic>),
    coordinates: (json['coordenadas'] as List)
        .map(
          (item) => BuildingCoordinate.fromJson(item as Map<String, dynamic>),
        )
        .toList(growable: false),
  );

  final String id;
  final String code;
  final String name;
  final String description;
  final BuildingCategory category;
  final String areaLabel;
  final String hours;
  final double coverageRadiusM;
  final List<String> dependencies;
  final List<String> tags;
  final String? photoAsset;
  final String? videoAsset;
  final MapFootprint? footprint;
  final String? photoUrl;
  final String? videoUrl;
  final List<BuildingCoordinate> coordinates;

  List<BuildingCoordinate> get entrances =>
      coordinates.where((coordinate) => coordinate.type.isEntrance).toList();

  BuildingCoordinate get mainEntrance => entrances.firstWhere(
    (coordinate) => coordinate.type == CoordinateType.entradaPrincipal,
    orElse: () => entrances.first,
  );

  String get searchText => foldForSearch(
    [
      code,
      name,
      areaLabel,
      description,
      hours,
      ...dependencies,
      ...tags,
    ].join(' '),
  );

  bool matches(String query) {
    final folded = foldForSearch(query.trim());
    if (folded.isEmpty) return true;
    final haystack = searchText;
    return folded.split(RegExp(r'\s+')).every(haystack.contains);
  }
}

/// Búsqueda insensible a mayúsculas y acentos ("rectoria" encuentra "Rectoría").
String foldForSearch(String input) {
  const replacements = {
    'á': 'a',
    'à': 'a',
    'ä': 'a',
    'â': 'a',
    'é': 'e',
    'è': 'e',
    'ë': 'e',
    'ê': 'e',
    'í': 'i',
    'ì': 'i',
    'ï': 'i',
    'î': 'i',
    'ó': 'o',
    'ò': 'o',
    'ö': 'o',
    'ô': 'o',
    'ú': 'u',
    'ù': 'u',
    'ü': 'u',
    'û': 'u',
    'ñ': 'n',
    'ç': 'c',
  };
  final buffer = StringBuffer();
  for (final char in input.toLowerCase().split('')) {
    buffer.write(replacements[char] ?? char);
  }
  return buffer.toString();
}

class Catalog {
  const Catalog({
    required this.version,
    required this.buildings,
    this.originLat,
    this.originLng,
    this.skipped = 0,
  });

  factory Catalog.fromJson(Map<String, dynamic> json) => Catalog(
    version: json['version'] as String? ?? '',
    buildings: (json['edificios'] as List)
        .map((item) => Building.fromJson(item as Map<String, dynamic>))
        .toList(growable: false),
  );

  final String version;
  final List<Building> buildings;

  /// Centro del catálogo (promedio de los puntos con coordenadas de la API).
  final double? originLat;

  /// Centro del catálogo (promedio de los puntos con coordenadas de la API).
  final double? originLng;

  /// Edificios descartados por no traer coordenadas (D-20).
  final int skipped;
}
