import 'package:flutter_test/flutter_test.dart';
import 'package:uthmap/core/geo.dart';
import 'package:uthmap/data/catalog_repository.dart';
import 'package:uthmap/data/models.dart';
import 'package:uthmap/data/sensor_prefs.dart';
import 'package:uthmap/state/nav_state.dart';
import 'package:uthmap/state/navigation_controller.dart';

/// Doble de [SensorPrefs] en memoria: no toca `SharedPreferences`.
class _FakeSensorPrefs implements SensorPrefs {
  double stored = 0;
  double? saved;

  @override
  Future<double> loadDeclinationDeg() async => stored;

  @override
  Future<void> saveDeclinationDeg(double value) async {
    saved = value;
    stored = value.clamp(-30.0, 30.0).toDouble();
  }
}

/// Copia de [building] con otro radio de cobertura.
Building _withCoverage(Building building, double coverageRadiusM) => Building(
  id: building.id,
  code: building.code,
  name: building.name,
  description: building.description,
  category: building.category,
  areaLabel: building.areaLabel,
  hours: building.hours,
  coverageRadiusM: coverageRadiusM,
  dependencies: building.dependencies,
  tags: building.tags,
  photoAsset: building.photoAsset,
  videoAsset: building.videoAsset,
  footprint: building.footprint,
  photoUrl: building.photoUrl,
  videoUrl: building.videoUrl,
  coordinates: building.coordinates,
);

Catalog _withBuildings(Catalog catalog, List<Building> buildings) => Catalog(
  version: catalog.version,
  buildings: buildings,
  originLat: catalog.originLat,
  originLng: catalog.originLng,
  skipped: catalog.skipped,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Catalog catalog;
  final t0 = DateTime(2026, 3, 10, 12, 0, 0);

  setUpAll(() async {
    catalog = await CatalogRepository().loadBundled();
  });

  test('gate: un fix impreciso no mueve la posición ni tumba el estado', () {
    final controller = NavigationController(catalog: catalog, clock: () => t0)
      ..debugUseRealSensors()
      ..clearTarget();
    final lat = controller.latitude;
    final lng = controller.longitude;

    controller.debugIngestFix(
      lat: campusOriginLat + 0.001,
      lng: campusOriginLng + 0.001,
      accuracyM: 31,
      timestamp: t0,
    );

    expect(controller.latitude, lat);
    expect(controller.longitude, lng);
    expect(controller.accuracyM, isNot(31));
    expect(controller.gpsStatus, SensorStatus.ok);
    expect(
      controller.sensorLogLines.where((line) => line.contains('fix rechazado')),
      hasLength(1),
    );

    controller.debugIngestFix(
      lat: campusOriginLat + 0.001,
      lng: campusOriginLng + 0.001,
      accuracyM: 31,
      timestamp: t0,
    );
    controller.debugIngestFix(
      lat: campusOriginLat + 0.001,
      lng: campusOriginLng + 0.001,
      accuracyM: 31,
      timestamp: t0,
    );

    expect(controller.gpsStatus, SensorStatus.noSignal);
    expect(controller.latitude, lat);

    controller.debugIngestFix(
      lat: campusOriginLat,
      lng: campusOriginLng,
      accuracyM: 5,
      timestamp: t0,
    );

    expect(controller.gpsStatus, SensorStatus.ok);
    expect(controller.latitude, closeTo(campusOriginLat, 1e-9));
  });

  test('declinación: se persiste, se restaura y corrige el rumbo', () async {
    final prefs = _FakeSensorPrefs();
    final controller = NavigationController(
      catalog: catalog,
      sensorPrefs: prefs,
      clock: () => t0,
    );

    await controller.loadSettings();
    expect(controller.declinationDeg, 0);

    controller.setHeading(0);
    await controller.setDeclinationDeg(10);

    expect(controller.declinationDeg, 10);
    expect(prefs.saved, 10);
    expect(controller.rawHeading, closeTo(10, 1e-6));
    expect(controller.heading, closeTo(10, 1e-6));

    await controller.setDeclinationDeg(45);
    expect(controller.declinationDeg, 30);
    expect(prefs.saved, 30);

    final restored = NavigationController(
      catalog: catalog,
      sensorPrefs: prefs,
      clock: () => t0,
    );
    await restored.loadSettings();
    await restored.loadSettings();

    expect(restored.declinationDeg, 30);
  });

  test('brújula: exactitud > 15° marca el sensor sin calibrar', () {
    final controller = NavigationController(catalog: catalog, clock: () => t0)
      ..debugUseRealSensors();

    controller.debugIngestCompass(heading: 0, accuracy: 20);

    expect(controller.compassAccuracyDeg, 20);
    expect(controller.compassStatus, SensorStatus.uncalibrated);

    controller.debugIngestCompass(heading: 0, accuracy: 10);

    expect(controller.compassAccuracyDeg, 10);
    expect(controller.compassStatus, SensorStatus.ok);
  });

  test('llegada: 11 m no llega y 9 m sí con radio de cobertura 10', () {
    final building = _withCoverage(catalog.buildings.first, 10);
    final controller = NavigationController(
      catalog: _withBuildings(catalog, [building]),
      clock: () => t0,
    )..debugUseRealSensors();

    controller.selectTarget(building);
    final entrance = building.mainEntrance.point;
    final far = moveBy(entrance, 0, 11);
    final near = moveBy(entrance, 0, 9);

    controller.debugIngestFix(
      lat: far.lat,
      lng: far.lng,
      accuracyM: 5,
      timestamp: t0,
    );

    expect(controller.distanceM, closeTo(11, 0.02));
    expect(controller.arrived, isFalse);

    controller.debugIngestFix(
      lat: near.lat,
      lng: near.lng,
      accuracyM: 5,
      timestamp: t0.add(const Duration(seconds: 5)),
    );

    expect(controller.distanceM, closeTo(9, 0.02));
    expect(controller.arrived, isTrue);
  });

  test('log: registra aceptados y rechazados sin pasar de 40 líneas', () {
    final controller = NavigationController(catalog: catalog, clock: () => t0)
      ..debugUseRealSensors()
      ..clearTarget();

    controller.debugIngestFix(
      lat: campusOriginLat,
      lng: campusOriginLng,
      accuracyM: 5,
      timestamp: t0,
    );
    controller.debugIngestFix(
      lat: campusOriginLat,
      lng: campusOriginLng,
      accuracyM: 31,
      timestamp: t0,
    );

    final lines = controller.sensorLogLines;

    expect(lines.any((line) => line.contains('fix ok')), isTrue);
    expect(lines.any((line) => line.contains('fix rechazado')), isTrue);
    expect(lines.length, lessThanOrEqualTo(40));

    for (var i = 0; i < 60; i++) {
      controller.debugIngestFix(
        lat: campusOriginLat + 0.002,
        lng: campusOriginLng,
        accuracyM: 31,
        timestamp: t0,
      );
    }

    expect(controller.sensorLogLines, hasLength(40));
  });

  test('simulación: setHeading sigue fijando el rumbo crudo', () {
    final controller = NavigationController(catalog: catalog);

    controller.setHeading(90);

    expect(controller.rawHeading, 90);
  });
}
