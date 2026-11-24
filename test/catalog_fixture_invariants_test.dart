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

List<Map<String, dynamic>> _rawBuildings(Map<String, dynamic> json) =>
    (json['data'] as List<dynamic>).cast<Map<String, dynamic>>();

/// Accesos que el mapper convierte en coordenada (lat/lng numéricos).
int _validAccessCount(Map<String, dynamic> raw) {
  var count = 0;
  for (final access in raw['accesos'] as List<dynamic>? ?? const []) {
    if (access is! Map<String, dynamic>) continue;
    if (access['latitud'] is num && access['longitud'] is num) count++;
  }
  return count;
}

/// Vértices de perímetro que el mapper acepta: lista [lat, lng] numérica.
int _perimeterVertexCount(Map<String, dynamic> raw) {
  var count = 0;
  for (final vertex in raw['perimetro'] as List<dynamic>? ?? const []) {
    if (vertex is! List || vertex.length < 2) continue;
    if (vertex[0] is num && vertex[1] is num) count++;
  }
  return count;
}

bool _hasCoordinates(Map<String, dynamic> raw) =>
    _validAccessCount(raw) > 0 || _perimeterVertexCount(raw) > 0;

Map<String, dynamic> _rawFor(Map<String, dynamic> json, Building building) =>
    _rawBuildings(json).firstWhere((raw) => raw['codigo'] == building.code);

/// Límite superior documentado del radio de cobertura (invariante 2: 20 m por
/// defecto; nada razonable por encima de 100 m).
const double _maxCoverageRadiusM = 100;

void main() {
  group('catálogo real de Orionis — invariantes del mapper', () {
    test('1. no vacío y buildings + skipped = elementos de data', () {
      final json = _fixtureJson();
      final catalog = catalogFromSincronizarV2(json);
      final rawBuildings = _rawBuildings(json);

      expect(catalog.buildings, isNotEmpty);
      expect(
        catalog.buildings.length + catalog.skipped,
        rawBuildings.length,
        reason: 'todo elemento de data entra al catálogo o suma a skipped',
      );

      final navigable = rawBuildings.where(_hasCoordinates).toList();
      expect(
        catalog.buildings.map((building) => building.code).toList(),
        navigable.map((raw) => raw['codigo'] as String).toList(),
        reason: 'el catálogo expone exactamente los edificios con coordenadas',
      );
      expect(catalog.skipped, rawBuildings.length - navigable.length);
    });

    test('2. todo edificio tiene coordenadas y mainEntrance no lanza', () {
      final catalog = catalogFromSincronizarV2(_fixtureJson());

      for (final building in catalog.buildings) {
        final label = '${building.code} (${building.name})';
        expect(building.coordinates, isNotEmpty, reason: label);
        expect(() => building.mainEntrance, returnsNormally, reason: label);
        expect(
          building.entrances,
          isNotEmpty,
          reason: '$label: Modo A necesita al menos una entrada',
        );
        expect(
          building.entrances,
          contains(building.mainEntrance),
          reason: '$label: mainEntrance debe ser una entrada',
        );
        final principales = building.entrances.where(
          (coordinate) => coordinate.type == CoordinateType.entradaPrincipal,
        );
        if (principales.isNotEmpty) {
          final mainEntrance = building.mainEntrance;
          expect(
            mainEntrance,
            isNotNull,
            reason: '$label: con entradas, mainEntrance no puede ser null',
          );
          expect(
            mainEntrance!.type,
            CoordinateType.entradaPrincipal,
            reason: '$label: con ENTRADA_PRINCIPAL, debe apuntar a ella',
          );
        }
      }
    });

    test(
      '3. entradas coherentes y coordenadas finitas distintas de (0, 0)',
      () {
        final catalog = catalogFromSincronizarV2(_fixtureJson());

        for (final building in catalog.buildings) {
          final label = '${building.code} (${building.name})';
          for (final entrance in building.entrances) {
            expect(building.entrances, isNotEmpty, reason: label);
            expect(entrance.type.isEntrance, isTrue, reason: label);
            expect(
              entrance.type,
              isNot(CoordinateType.perimetro),
              reason: '$label: entrances no debe contener perímetro',
            );
          }
          for (final coordinate in building.coordinates) {
            expect(coordinate.lat.isFinite, isTrue, reason: '$label lat');
            expect(coordinate.lng.isFinite, isTrue, reason: '$label lng');
            expect(coordinate.lat.isNaN, isFalse, reason: '$label lat');
            expect(coordinate.lng.isNaN, isFalse, reason: '$label lng');
            expect(
              coordinate.lat == 0 && coordinate.lng == 0,
              isFalse,
              reason: '$label: coordenada (0, 0) rompería la aguja',
            );
          }
        }
      },
    );

    test(
      '4. originLat/Lng no nulos y dentro del bounding box de coordenadas',
      () {
        final catalog = catalogFromSincronizarV2(_fixtureJson());
        final points = [
          for (final building in catalog.buildings) ...building.coordinates,
        ];

        expect(points, isNotEmpty);
        expect(catalog.originLat, isNotNull);
        expect(catalog.originLng, isNotNull);

        final minLat = points
            .map((coordinate) => coordinate.lat)
            .reduce((a, b) => a < b ? a : b);
        final maxLat = points
            .map((coordinate) => coordinate.lat)
            .reduce((a, b) => a > b ? a : b);
        final minLng = points
            .map((coordinate) => coordinate.lng)
            .reduce((a, b) => a < b ? a : b);
        final maxLng = points
            .map((coordinate) => coordinate.lng)
            .reduce((a, b) => a > b ? a : b);

        expect(catalog.originLat, inInclusiveRange(minLat, maxLat));
        expect(catalog.originLng, inInclusiveRange(minLng, maxLng));
      },
    );

    test('5. footprint: medidas positivas y null con perímetro < 3 (D-21)', () {
      final json = _fixtureJson();
      final catalog = catalogFromSincronizarV2(json);

      for (final building in catalog.buildings) {
        final label = '${building.code} (${building.name})';
        final vertices = _perimeterVertexCount(_rawFor(json, building));
        final footprint = building.footprint;

        if (footprint == null) {
          expect(
            vertices,
            lessThan(3),
            reason: '$label: perímetro $vertices no debe quedar sin huella',
          );
          continue;
        }

        expect(vertices, greaterThanOrEqualTo(3), reason: label);
        expect(footprint.width, greaterThan(0), reason: label);
        expect(footprint.depth, greaterThan(0), reason: label);
        expect(footprint.height, defaultBuildingHeightM, reason: label);
      }
    });

    test('6. radio_cobertura > 0 y <= 100 en todo el catálogo', () {
      final json = _fixtureJson();
      final catalog = catalogFromSincronizarV2(json);

      for (final building in catalog.buildings) {
        final label = '${building.code} (${building.name})';
        final raw = _rawFor(json, building);
        final rawRadius = raw['radio_cobertura'];

        expect(building.coverageRadiusM, greaterThan(0), reason: label);
        expect(
          building.coverageRadiusM,
          lessThanOrEqualTo(_maxCoverageRadiusM),
          reason: label,
        );
        if (rawRadius is num) {
          expect(
            building.coverageRadiusM,
            rawRadius.toDouble(),
            reason: '$label: el mapper debe respetar radio_cobertura',
          );
        }
      }
    });
  });
}
