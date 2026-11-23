import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:uthmap/core/geo.dart';
import 'package:uthmap/data/catalog_repository.dart';
import 'package:uthmap/data/models.dart';
import 'package:uthmap/state/navigation_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const originLat = 20.08123456;
  const originLng = -98.76123456;
  const catalogOrigin = GeoPoint(originLat, originLng);

  const synthetic = Catalog(
    version: 't',
    buildings: [],
    originLat: originLat,
    originLng: originLng,
  );

  test('Caso A: el catálogo aporta el origen de la proyección (D-26)', () {
    final controller = NavigationController(catalog: synthetic);
    addTearDown(controller.dispose);

    expect(controller.origin.lat, originLat);
    expect(controller.origin.lng, originLng);

    final local = projectToCampus(catalogOrigin, origin: controller.origin);
    expect(local.east, closeTo(0, 1e-6));
    expect(local.north, closeTo(0, 1e-6));

    // Con el origen global por defecto el mismo punto cae a cientos de km.
    final global = projectToCampus(catalogOrigin);
    final distance = math.sqrt(
      global.east * global.east + global.north * global.north,
    );
    expect(distance, greaterThan(100000));
  });

  test('Caso B: campusPoint(0, 0) devuelve el origen', () {
    final point = campusPoint(0, 0, origin: catalogOrigin);
    expect(point.lat, closeTo(originLat, 1e-9));
    expect(point.lng, closeTo(originLng, 1e-9));
  });

  test('Caso C: round-trip proyección ↔ campusPoint', () {
    final point = campusPoint(40, -30, origin: catalogOrigin);
    final local = projectToCampus(point, origin: catalogOrigin);
    expect(local.east, closeTo(40, 0.01));
    expect(local.north, closeTo(-30, 0.01));
  });

  test('Caso D: catálogo bundled sin origen usa el global', () async {
    final catalog = await CatalogRepository().loadBundled();
    expect(catalog.originLat, isNull);
    expect(catalog.originLng, isNull);

    final controller = NavigationController(catalog: catalog);
    addTearDown(controller.dispose);

    expect(controller.origin.lat, campusOriginLat);
    expect(controller.origin.lng, campusOriginLng);

    controller.resetDemo();
    expect(controller.latitude, closeTo(campusOriginLat, 1e-9));
    expect(controller.longitude, closeTo(campusOriginLng, 1e-9));
  });
}
