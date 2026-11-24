import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:uthmap/data/catalog_v2_mapper.dart';
import 'package:uthmap/data/models.dart';

/// Respuesta real de `/sincronizar_v2` capturada de Orionis (no inventada).
Map<String, dynamic> _fixtureJson() {
  final raw = File('test/fixtures/orionis_sincronizar_v2.json')
      .readAsStringSync();
  return jsonDecode(raw) as Map<String, dynamic>;
}

Building _building(List<BuildingCoordinate> coordinates) => Building(
  id: 'x',
  code: 'X',
  name: 'Edificio X',
  description: '',
  category: BuildingCategory.academico,
  areaLabel: '',
  hours: '',
  coverageRadiusM: 20,
  dependencies: const [],
  tags: const [],
  photoAsset: null,
  videoAsset: null,
  coordinates: coordinates,
);

BuildingCoordinate _coordinate(CoordinateType type, double lat, double lng) =>
    BuildingCoordinate(type: type, lat: lat, lng: lng);

void main() {
  group('Building.mainEntrance', () {
    test(
      '1. con ENTRADA_PRINCIPAL y ENTRADA_SECUNDARIA devuelve la principal',
      () {
        final building = _building([
          _coordinate(CoordinateType.entradaSecundaria, 29.001, -110.901),
          _coordinate(CoordinateType.entradaPrincipal, 29.002, -110.902),
        ]);

        final mainEntrance = building.mainEntrance;

        expect(mainEntrance, isNotNull);
        expect(mainEntrance!.type, CoordinateType.entradaPrincipal);
        expect(mainEntrance.lat, 29.002);
        expect(mainEntrance.lng, -110.902);
      },
    );

    test('2. solo con ENTRADA_SECUNDARIA devuelve esa entrada', () {
      final building = _building([
        _coordinate(CoordinateType.perimetro, 29.003, -110.903),
        _coordinate(CoordinateType.entradaSecundaria, 29.004, -110.904),
      ]);

      final mainEntrance = building.mainEntrance;

      expect(mainEntrance, isNotNull);
      expect(mainEntrance!.type, CoordinateType.entradaSecundaria);
      expect(mainEntrance.lat, 29.004);
    });

    test('3. solo con PERIMETRO devuelve null y no lanza', () {
      final building = _building([
        _coordinate(CoordinateType.perimetro, 29.005, -110.905),
      ]);

      expect(building.entrances, isEmpty);
      expect(() => building.mainEntrance, returnsNormally);
      expect(building.mainEntrance, isNull);
    });

    test('4. sin coordenadas devuelve null y no lanza', () {
      final building = _building(const []);

      expect(building.coordinates, isEmpty);
      expect(() => building.mainEntrance, returnsNormally);
      expect(building.mainEntrance, isNull);
    });

    test('5. catálogo real: ningún edificio lanza al pedir mainEntrance', () {
      final catalog = catalogFromSincronizarV2(_fixtureJson());

      expect(catalog.buildings, isNotEmpty);
      for (final building in catalog.buildings) {
        final label = '${building.code} (${building.name})';
        expect(() => building.mainEntrance, returnsNormally, reason: label);
        final mainEntrance = building.mainEntrance;
        if (mainEntrance != null) {
          expect(building.entrances, contains(mainEntrance), reason: label);
        }
      }
    });
  });
}
