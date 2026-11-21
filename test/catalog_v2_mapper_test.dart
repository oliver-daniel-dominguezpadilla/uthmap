import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:uthmap/data/catalog_v2_mapper.dart';
import 'package:uthmap/data/models.dart';

/// Respuesta cruda capturada con `curl.exe` (no inventada).
Map<String, dynamic> _fixture() {
  final raw = File('test/fixtures/orionis_sincronizar_v2.json')
      .readAsStringSync();
  return jsonDecode(raw) as Map<String, dynamic>;
}

/// Payload mínimo para probar transformaciones aisladas.
Map<String, dynamic> _minimalPayload({
  String categoryName = 'Académico',
  String? fotoUrl,
  String? videoUrl,
  bool success = true,
}) => {
  'success': success,
  'ultima_actualizacion': '2026-11-03T04:22:33+00:00',
  'data': [
    {
      'id': 1,
      'codigo': 'X',
      'nombre': 'Edificio X',
      'descripcion': null,
      'dependencias': 'Uno, Dos',
      'radio_cobertura': 20,
      'foto_url': fotoUrl,
      'url_video': videoUrl,
      'categoria': {'id': 1, 'nombre': categoryName},
      'etiquetas': ['a', 'b'],
      'coordenada_central': null,
      'accesos': [
        {
          'id': 1,
          'nombre': 'Entrada',
          'latitud': 29.0084,
          'longitud': -110.9022,
          'tipo_punto': 'ENTRADA_PRINCIPAL',
          'es_principal': true,
        },
      ],
      'perimetro': <dynamic>[],
    },
  ],
};

void main() {
  group('catalogFromSincronizarV2', () {
    test('la fixture real parsea: success true y 5 edificios', () {
      final json = _fixture();
      expect(json['success'], isTrue);
      expect(json['data'], isA<List<dynamic>>());
      expect(json['data'] as List<dynamic>, hasLength(5));
    });

    test('devuelve 3 edificios navegables (B, D, E) y descarta 2', () {
      final catalog = catalogFromSincronizarV2(_fixture());
      expect(catalog.buildings.map((building) => building.code).toList(), [
        'B',
        'D',
        'E',
      ]);
      expect(catalog.skipped, 2);
      expect(catalog.version, '2026-11-03T04:22:33+00:00');
    });

    test('edificio B: 4 accesos secundarios + 1 vértice, sin huella', () {
      final catalog = catalogFromSincronizarV2(_fixture());
      final b = catalog.buildings.firstWhere(
        (building) => building.code == 'B',
      );
      expect(b.coordinates, hasLength(5));
      expect(
        b.coordinates.where(
          (coordinate) => coordinate.type == CoordinateType.entradaSecundaria,
        ),
        hasLength(4),
      );
      expect(
        b.coordinates.where(
          (coordinate) => coordinate.type == CoordinateType.perimetro,
        ),
        hasLength(1),
      );
      expect(b.footprint, isNull);
      expect(b.photoUrl, isNull);
      expect(b.videoUrl, isNull);
      expect(b.category, BuildingCategory.administrativo);
      expect(b.coverageRadiusM, 20);
    });

    test('edificio D: ambos accesos principales y el marcado va primero', () {
      final json = _fixture();
      final raw = (json['data'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .firstWhere((building) => building['codigo'] == 'D');
      final main = (raw['accesos'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .firstWhere((acceso) => acceso['es_principal'] == true);
      expect(main['id'], 41);

      final catalog = catalogFromSincronizarV2(json);
      final d = catalog.buildings.firstWhere(
        (building) => building.code == 'D',
      );
      expect(d.coordinates, hasLength(4));
      expect(
        d.coordinates.where(
          (coordinate) => coordinate.type == CoordinateType.entradaPrincipal,
        ),
        hasLength(2),
      );
      expect(d.coordinates.first.type, CoordinateType.entradaPrincipal);
      expect(d.coordinates.first.lat, closeTo(29.00919, 1e-6));
      expect(
        d.coordinates.first.lat,
        closeTo((main['latitud'] as num).toDouble(), 1e-9),
      );
      expect(d.footprint, isNull);
    });

    test('edificio E: 1 acceso + 4 vértices y huella con altura fija', () {
      final catalog = catalogFromSincronizarV2(_fixture());
      final e = catalog.buildings.firstWhere(
        (building) => building.code == 'E',
      );
      expect(e.coordinates, hasLength(5));
      expect(
        e.coordinates.where(
          (coordinate) => coordinate.type == CoordinateType.perimetro,
        ),
        hasLength(4),
      );
      expect(e.coordinates.first.type, CoordinateType.entradaPrincipal);

      final footprint = e.footprint;
      expect(footprint, isNotNull);
      expect(footprint!.width, greaterThan(0));
      expect(footprint.depth, greaterThan(0));
      expect(footprint.height, 10);
      expect(footprint.height, defaultBuildingHeightM);
    });

    test('origen del catálogo = promedio de los puntos con coordenadas', () {
      final catalog = catalogFromSincronizarV2(_fixture());
      expect(catalog.originLat, closeTo(29.0089, 0.01));
      expect(catalog.originLng, closeTo(-110.9024, 0.01));

      final points = [
        for (final building in catalog.buildings) ...building.coordinates,
      ];
      final meanLat =
          points.fold<double>(0, (sum, point) => sum + point.lat) /
          points.length;
      final meanLng =
          points.fold<double>(0, (sum, point) => sum + point.lng) /
          points.length;
      expect(catalog.originLat, closeTo(meanLat, 1e-12));
      expect(catalog.originLng, closeTo(meanLng, 1e-12));
    });

    test('id numérico se convierte a String', () {
      final catalog = catalogFromSincronizarV2(_fixture());
      final b = catalog.buildings.firstWhere(
        (building) => building.code == 'B',
      );
      expect(b.id, '26');
    });

    test('categorías según D-23', () {
      BuildingCategory categoryOf(String name) =>
          catalogFromSincronizarV2(_minimalPayload(categoryName: name))
              .buildings
              .single
              .category;

      expect(categoryOf('Académico'), BuildingCategory.academico);
      expect(categoryOf('Administrativo'), BuildingCategory.administrativo);
      expect(
        categoryOf('Área Común / Convivencia'),
        BuildingCategory.servicios,
      );
      expect(categoryOf('Laboratorio / Taller'), BuildingCategory.servicios);
    });

    test('foto_url y url_video vacíos se normalizan a null', () {
      final catalog = catalogFromSincronizarV2(
        _minimalPayload(fotoUrl: '', videoUrl: ''),
      );
      final building = catalog.buildings.single;
      expect(building.photoUrl, isNull);
      expect(building.videoUrl, isNull);
      expect(building.dependencies, ['Uno', 'Dos']);
    });

    test('success distinto de true lanza FormatException', () {
      expect(
        () => catalogFromSincronizarV2(_minimalPayload(success: false)),
        throwsFormatException,
      );
      expect(
        () => catalogFromSincronizarV2({'success': true, 'data': null}),
        throwsFormatException,
      );
    });
  });
}
