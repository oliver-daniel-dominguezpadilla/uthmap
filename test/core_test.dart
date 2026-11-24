import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uthmap/core/geo.dart';
import 'package:uthmap/core/geofence.dart';
import 'package:uthmap/data/models.dart';

Future<Catalog> _loadCatalog() async {
  final raw = await rootBundle.loadString('assets/data/edificios.json');
  return Catalog.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Haversine y rumbo', () {
    test('111.32 m por grado de latitud', () {
      final distance = haversineM(19.0, -98.2, 19.001, -98.2);
      expect(distance, closeTo(111.32, 0.5));
    });

    test('distancias simétricas', () {
      final a = haversineM(19.0, -98.2, 19.0031, -98.1982);
      final b = haversineM(19.0031, -98.1982, 19.0, -98.2);
      expect(a, closeTo(b, 1e-9));
    });

    test('rumbos cardinales', () {
      expect(initialBearingDeg(0, 0, 0.001, 0), closeTo(0, 0.001));
      expect(initialBearingDeg(0, 0, 0, 0.001), closeTo(90, 0.001));
      expect(initialBearingDeg(0, 0, -0.001, 0), closeTo(180, 0.001));
      expect(initialBearingDeg(0, 0, 0, -0.001), closeTo(270, 0.001));
    });

    test('aguja = rumbo - heading normalizado', () {
      expect(needleAngleDeg(123, 278), closeTo(205, 1e-9));
      expect(needleAngleDeg(10, 350), closeTo(20, 1e-9));
      expect(needleAngleDeg(350, 10), closeTo(340, 1e-9));
    });

    test('diferencia angular más corta', () {
      expect(shortestDeltaDeg(359, 1), closeTo(2, 1e-9));
      expect(shortestDeltaDeg(1, 359), closeTo(-2, 1e-9));
    });
  });

  group('Cuadrantes del reto mayor', () {
    test('al frente', () {
      expect(quadrantLabel(0), 'Al frente');
      expect(quadrantLabel(44.9), 'Al frente');
      expect(quadrantLabel(315), 'Al frente');
      expect(quadrantLabel(359.9), 'Al frente');
    });

    test('derecha, espaldas e izquierda', () {
      expect(quadrantLabel(45), 'A tu derecha');
      expect(quadrantLabel(134.9), 'A tu derecha');
      expect(quadrantLabel(135), 'A tus espaldas');
      expect(quadrantLabel(205), 'A tus espaldas');
      expect(quadrantLabel(225), 'A tu izquierda');
      expect(quadrantLabel(314.9), 'A tu izquierda');
    });

    test('frase accionable', () {
      expect(quadrantHint(0), 'Al frente, sigue recto');
      expect(quadrantHint(90), 'A tu derecha, gira a la derecha');
      expect(quadrantHint(160), 'A tus espaldas, gira a la derecha');
      expect(quadrantHint(205), 'A tus espaldas, gira a la izquierda');
      expect(quadrantHint(270), 'A tu izquierda, gira a la izquierda');
    });
  });

  group('Geocerca con histéresis', () {
    test('entra a 20 m y sale a más de 25 m', () {
      expect(
        geofenceInside(distanceM: 20, radiusM: 20, wasInside: false),
        isTrue,
      );
      expect(
        geofenceInside(distanceM: 20.1, radiusM: 20, wasInside: false),
        isFalse,
      );
      expect(
        geofenceInside(distanceM: 25, radiusM: 20, wasInside: true),
        isTrue,
      );
      expect(
        geofenceInside(distanceM: 25.1, radiusM: 20, wasInside: true),
        isFalse,
      );
    });
  });

  group('Filtro pasa-bajas', () {
    test('cruza 359 -> 1 por el camino corto', () {
      final filter = LowPassAngle(0.15, 359);
      expect(filter.filter(1), closeTo(359.3, 1e-9));
    });

    test('cruza 1 -> 359 por el camino corto', () {
      final filter = LowPassAngle(0.15, 1);
      expect(filter.filter(359), closeTo(0.7, 1e-9));
    });

    test('respeta el valor inicial sin muestras', () {
      final filter = LowPassAngle(0.15, 278);
      expect(filter.hasValue, isTrue);
      expect(filter.value, 278);
    });
  });

  group('Vectores de docs/02', () {
    const baseLat = 20.08123456;
    const baseLng = -98.76123456;

    test('haversine y bearing en ecuador y meridiano', () {
      expect(haversineM(0, 0, 0, 1), closeTo(111194.927, 0.01));
      expect(initialBearingDeg(0, 0, 0, 1), closeTo(90.0, 0.01));
      expect(haversineM(0, 0, 1, 0), closeTo(111194.927, 0.01));
      expect(initialBearingDeg(0, 0, 1, 0), closeTo(0.0, 0.01));
    });

    test('100 m al norte y 100 m al este desde el punto base', () {
      expect(
        haversineM(baseLat, baseLng, 20.08213388, -98.76123456),
        closeTo(99.9998, 0.01),
      );
      expect(
        initialBearingDeg(baseLat, baseLng, 20.08213388, -98.76123456),
        closeTo(0.0, 0.01),
      );
      expect(
        haversineM(baseLat, baseLng, 20.08123456, -98.76027703),
        closeTo(99.9997, 0.01),
      );
      expect(
        initialBearingDeg(baseLat, baseLng, 20.08123456, -98.76027703),
        closeTo(89.9998, 0.01),
      );
    });

    test('17 m al noroeste desde el punto base', () {
      expect(
        haversineM(baseLat, baseLng, 20.08134567, -98.76134567),
        closeTo(16.9496, 0.01),
      );
      expect(
        initialBearingDeg(baseLat, baseLng, 20.08134567, -98.76134567),
        closeTo(316.7956, 0.01),
      );
    });

    test('distancia al mismo punto es cero', () {
      expect(haversineM(baseLat, baseLng, baseLat, baseLng), 0.0);
    });

    test('aguja sin giro cuando rumbo y heading coinciden', () {
      // 10 -> 350 y 350 -> 10 ya están cubiertos en 'Haversine y rumbo'.
      expect(needleAngleDeg(90, 90), 0);
    });

    test('borde inferior del cuadrante al frente', () {
      // El resto de bordes (0, 45, 135, 225, 315, 359.9) ya están
      // cubiertos en 'Cuadrantes del reto mayor'.
      expect(quadrantLabel(44.99), 'Al frente');
    });

    test('filtro arranca con la primera muestra (359 -> 1)', () {
      final northward = LowPassAngle(0.15);
      expect(northward.filter(359), closeTo(359, 1e-9));
      expect(northward.filter(1), closeTo(359.3, 1e-9));
    });

    test('filtro vuelve desde el norte hacia atrás (1 -> 359)', () {
      final southward = LowPassAngle(0.15);
      expect(southward.filter(1), closeTo(1, 1e-9));
      expect(southward.filter(359), closeTo(0.7, 1e-9));
    });

    test('filtro con alpha 0.2 se acerca a la muestra', () {
      final filter = LowPassAngle(0.2);
      expect(filter.filter(10), closeTo(10, 1e-9));
      expect(filter.filter(20), closeTo(12.0, 1e-9));
    });
  });

  group('Radio de llegada', () {
    test('nunca supera la cobertura del edificio', () {
      expect(arrivalRadiusM(20), 15);
      expect(arrivalRadiusM(10), 10);
      expect(arrivalRadiusM(15), 15);
    });
  });

  group('Catálogo 1:N', () {
    test('carga 5 edificios y 30 coordenadas', () async {
      final catalog = await _loadCatalog();
      expect(catalog.buildings, hasLength(5));
      expect(
        catalog.buildings.fold<int>(
          0,
          (total, building) => total + building.coordinates.length,
        ),
        30,
      );
      for (final building in catalog.buildings) {
        expect(
          building.coordinates.where(
            (coordinate) => coordinate.type == CoordinateType.entradaPrincipal,
          ),
          hasLength(1),
        );
        expect(
          building.coordinates.where(
            (coordinate) => coordinate.type == CoordinateType.entradaSecundaria,
          ),
          hasLength(1),
        );
        expect(
          building.coordinates.where(
            (coordinate) => coordinate.type == CoordinateType.perimetro,
          ),
          hasLength(4),
        );
      }
    });

    test('estado inicial del wireframe: 145 m / 123° / 205°', () async {
      final catalog = await _loadCatalog();
      final k = catalog.buildings.first;
      final entrance = k.mainEntrance;
      expect(entrance, isNotNull);
      final distance = haversineM(
        campusOriginLat,
        campusOriginLng,
        entrance!.lat,
        entrance.lng,
      );
      final bearing = initialBearingDeg(
        campusOriginLat,
        campusOriginLng,
        entrance.lat,
        entrance.lng,
      );
      expect(distance.round(), 145);
      expect(bearing, closeTo(123, 0.2));
      expect(needleAngleDeg(bearing, 278), closeTo(205, 0.2));
      expect(
        quadrantHint(needleAngleDeg(bearing, 278)),
        'A tus espaldas, gira a la izquierda',
      );
    });

    test('búsqueda sin acentos por nombre, dependencia y etiqueta', () async {
      final catalog = await _loadCatalog();
      final rectory = catalog.buildings.firstWhere(
        (building) => building.code == 'R',
      );
      final computing = catalog.buildings.firstWhere(
        (building) => building.code == 'M',
      );
      expect(rectory.matches('rectoria'), isTrue);
      expect(rectory.matches('RECURSOS HUMANOS'), isTrue);
      expect(computing.matches('computo'), isTrue);
      expect(computing.matches('laboratorio redes'), isTrue);
      expect(computing.matches('biblioteca'), isFalse);
    });
  });
}
