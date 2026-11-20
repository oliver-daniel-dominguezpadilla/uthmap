import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';

import '../core/geo.dart';
import '../core/geofence.dart';
import '../data/models.dart';
import '../state/nav_state.dart';

enum GpsSimulation { ok, denied, disabled, noSignal }

/// Motor de navegación del prototipo. Los cálculos viven en core/ y aquí solo
/// se orquesta el estado, la simulación y (opcionalmente) los sensores reales.
class NavigationController extends ChangeNotifier {
  NavigationController({required this.catalog}) {
    _reset(notify: false);
  }

  final Catalog catalog;

  static const Duration _tickDuration = Duration(milliseconds: 300);
  static const double _stepM = 3;
  static const double _arrivalM = 15;
  static const double _accuracyLimitM = 30;

  late Building? _target;
  double _lat = campusOriginLat;
  double _lng = campusOriginLng;
  double _rawHeading = 278;
  double _heading = 278;
  final LowPassAngle _filter = LowPassAngle(0.15, 278);
  double? _accuracy = 6;
  GpsSimulation _gpsSimulation = GpsSimulation.ok;
  bool _compassUncalibrated = false;
  bool _walking = false;
  bool _arrived = false;
  bool _arrivalNotified = false;
  Building? _nearby;
  Timer? _ticker;
  int _routeIndex = 1;

  bool _realSensors = false;
  SensorStatus _realGpsStatus = SensorStatus.ok;
  SensorStatus _realCompassStatus = SensorStatus.ok;
  StreamSubscription<Position>? _positionSub;
  StreamSubscription<CompassEvent>? _compassSub;
  bool _disposed = false;

  /// La pantalla de navegación lo usa para abrir la ficha al llegar.
  ValueChanged<Building>? onArrival;

  List<Building> get buildings => catalog.buildings;

  GeoPoint get position => GeoPoint(_lat, _lng);

  double get latitude => _lat;

  double get longitude => _lng;

  double get rawHeading => _rawHeading;

  double get heading => _heading;

  double? get accuracyM => _accuracy;

  bool get walking => _walking;

  bool get realSensors => _realSensors;

  GpsSimulation get gpsSimulation => _gpsSimulation;

  bool get compassUncalibrated => _compassUncalibrated;

  Building? get target => _target;

  Building? get nearby => _nearby;

  bool get arrived => _arrived;

  NavMode get mode => _target == null ? NavMode.explore : NavMode.directed;

  SensorStatus get gpsStatus {
    if (_realSensors) return _realGpsStatus;
    return switch (_gpsSimulation) {
      GpsSimulation.ok => SensorStatus.ok,
      GpsSimulation.denied => SensorStatus.denied,
      GpsSimulation.disabled => SensorStatus.disabled,
      GpsSimulation.noSignal => SensorStatus.noSignal,
    };
  }

  SensorStatus get compassStatus {
    if (_compassUncalibrated && !_realSensors) {
      return SensorStatus.uncalibrated;
    }
    return _realCompassStatus;
  }

  bool get gpsUsable => gpsStatus == SensorStatus.ok;

  String? get gpsMessage => switch (gpsStatus) {
    SensorStatus.denied => 'Permiso de ubicación denegado. Habilítalo en Ajustes para navegar; el directorio sigue disponible.',
    SensorStatus.disabled =>
      'La ubicación del dispositivo está apagada. Actívala para navegar.',
    SensorStatus.noSignal =>
      'Señal GPS débil (más de 30 m de precisión). La geocerca está en pausa.',
    _ => null,
  };

  String? get compassMessage => compassStatus == SensorStatus.uncalibrated
      ? 'Brújula sin calibrar. Dibuja un ocho en el aire o usa el rumbo numérico.'
      : null;

  NearestPoint? get _directedPoint {
    final building = _target;
    if (building == null) return null;
    final from = position;
    return nearestOf(
          from,
          building.entrances.map((coordinate) => coordinate.point),
        ) ??
        nearestOf(
          from,
          building.coordinates.map((coordinate) => coordinate.point),
        );
  }

  /// Punto exacto del acceso hacia el que apunta la aguja (para el mapa).
  GeoPoint? get targetPoint => _directedPoint?.point;

  double? get distanceM {
    final directed = _directedPoint;
    if (directed != null) return directed.distanceM;
    return _nearestBuilding()?.point.distanceM;
  }

  double? get bearingDeg {
    final point = targetPoint ?? _nearestBuilding()?.point.point;
    if (point == null) return null;
    return initialBearingDeg(_lat, _lng, point.lat, point.lng);
  }

  double? get needleDeg {
    final bearing = bearingDeg;
    return bearing == null ? null : needleAngleDeg(bearing, _heading);
  }

  String? get quadrantLabelText {
    final needle = needleDeg;
    return needle == null ? null : quadrantLabel(needle);
  }

  String? get quadrantHintText {
    final needle = needleDeg;
    if (needle == null) return null;
    if (_arrived) return 'Estás en el acceso, abre la ficha completa';
    return quadrantHint(needle);
  }

  bool get insideTargetArea {
    final building = _target;
    final distance = _directedPoint?.distanceM;
    if (building == null || distance == null) return false;
    return distance <= building.coverageRadiusM;
  }

  double? nearestDistanceTo(Building building) => nearestOf(
    position,
    building.coordinates.map((coordinate) => coordinate.point),
  )?.distanceM;

  NearestPoint? nearestEntranceTo(Building building) => nearestOf(
    position,
    building.entrances.map((coordinate) => coordinate.point),
  );

  NavState get state => NavState(
    mode: mode,
    distanceM: distanceM,
    needleDeg: needleDeg,
    bearingDeg: bearingDeg,
    headingDeg: _heading,
    quadrant: quadrantLabelText,
    target: _target,
    nearby: _nearby,
    arrived: _arrived,
    gps: gpsStatus,
    compass: compassStatus,
    accuracyM: _accuracy,
  );

  ({Building building, NearestPoint point})? _nearestBuilding() {
    ({Building building, NearestPoint point})? best;
    for (final building in buildings) {
      final nearest = nearestOf(
        position,
        building.coordinates.map((coordinate) => coordinate.point),
      );
      if (nearest == null) continue;
      if (best == null || nearest.distanceM < best.point.distanceM) {
        best = (building: building, point: nearest);
      }
    }
    return best;
  }

  void _reset({bool notify = true}) {
    _stopTicker();
    _lat = campusOriginLat;
    _lng = campusOriginLng;
    _rawHeading = 278;
    _heading = 278;
    _filter.reset(278);
    _accuracy = 6;
    _gpsSimulation = GpsSimulation.ok;
    _compassUncalibrated = false;
    _walking = false;
    _arrived = false;
    _arrivalNotified = false;
    _nearby = null;
    _routeIndex = 1;
    _target = buildings.isEmpty ? null : buildings.first;
    if (notify) _notify();
  }

  void resetDemo() => _reset();

  void selectTarget(Building? building) {
    _target = building;
    _arrived = false;
    _arrivalNotified = false;
    _nearby = null;
    _walking = false;
    _routeIndex = 1;
    _stopTicker();
    _notify();
  }

  void clearTarget() => selectTarget(null);

  void setHeading(double degrees) {
    _rawHeading = normalizeDegrees(degrees);
    _heading = _filter.filter(_rawHeading);
    _notify();
  }

  void alignHeading() {
    final bearing = bearingDeg;
    if (bearing == null) return;
    _rawHeading = bearing;
    _heading = bearing;
    _filter.reset(bearing);
    _notify();
  }

  void toggleWalking() {
    if (_realSensors) return;
    if (!gpsUsable) return;
    _walking = !_walking;
    if (_walking) {
      _arrived = false;
      _ticker?.cancel();
      _ticker = Timer.periodic(_tickDuration, (_) => _tick());
    } else {
      _stopTicker();
    }
    _notify();
  }

  void setGpsSimulation(GpsSimulation simulation) {
    if (_realSensors) return;
    _gpsSimulation = simulation;
    if (simulation != GpsSimulation.ok) {
      _nearby = null;
      _stopTicker();
      _walking = false;
    }
    _notify();
  }

  void setCompassUncalibrated(bool value) {
    if (_realSensors) return;
    _compassUncalibrated = value;
    _notify();
  }

  void _tick() {
    if (!_walking || !gpsUsable) return;

    if (_target != null) {
      final point = _directedPoint;
      if (point == null) return;
      if (point.distanceM <= _arrivalM) {
        _handleArrival();
        return;
      }
      _moveToward(point.point, _stepM);
      final updated = _directedPoint;
      if (updated != null && updated.distanceM <= _arrivalM) {
        _handleArrival();
        return;
      }
    } else {
      _moveAlongRoute(_stepM);
      _evaluateGeofence();
    }

    _notify();
  }

  void _handleArrival() {
    if (_arrived) return;
    _arrived = true;
    _walking = false;
    _stopTicker();
    _alert();
    final building = _target;
    if (building != null && !_arrivalNotified) {
      _arrivalNotified = true;
      onArrival?.call(building);
    }
    _notify();
  }

  void _moveToward(GeoPoint destination, double distanceM) {
    final bearing = initialBearingDeg(
      _lat,
      _lng,
      destination.lat,
      destination.lng,
    );
    final next = moveBy(position, bearing, distanceM);
    _lat = next.lat;
    _lng = next.lng;
  }

  void _moveAlongRoute(double distanceM) {
    final waypoint = _exploreRoute[_routeIndex % _exploreRoute.length];
    final point = campusPoint(waypoint.east, waypoint.north);
    final remaining = haversineM(_lat, _lng, point.lat, point.lng);
    if (remaining <= distanceM) {
      _lat = point.lat;
      _lng = point.lng;
      _routeIndex = (_routeIndex + 1) % _exploreRoute.length;
    } else {
      _moveToward(point, distanceM);
    }
  }

  void _evaluateGeofence() {
    if (!gpsUsable) {
      _nearby = null;
      return;
    }

    final active = _nearby;
    if (active != null) {
      final distance = nearestDistanceTo(active);
      if (distance != null &&
          geofenceInside(
            distanceM: distance,
            radiusM: active.coverageRadiusM,
            wasInside: true,
          )) {
        return;
      }
      _nearby = null;
    }

    final nearest = _nearestBuilding();
    if (nearest == null) return;
    if (nearest.point.distanceM <= nearest.building.coverageRadiusM) {
      _nearby = nearest.building;
      _alert();
    }
  }

  void _alert() {
    unawaited(HapticFeedback.heavyImpact());
    unawaited(SystemSound.play(SystemSoundType.alert));
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
    _walking = false;
  }

  Future<void> setRealSensors(bool enabled) async {
    if (enabled == _realSensors) return;
    _stopTicker();
    _walking = false;
    await _cancelSensorStreams();
    _realSensors = enabled;
    _realGpsStatus = SensorStatus.ok;
    _realCompassStatus = SensorStatus.ok;

    if (!enabled) {
      _notify();
      return;
    }

    _notify();

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _realGpsStatus = SensorStatus.disabled;
        _notify();
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _realGpsStatus = SensorStatus.denied;
        _notify();
        return;
      }

      _positionSub =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 2,
            ),
          ).listen(
            _onRealPosition,
            onError: (_) {
              _realGpsStatus = SensorStatus.noSignal;
              _notify();
            },
          );
      _realGpsStatus = SensorStatus.ok;
      _notify();
    } catch (_) {
      _realGpsStatus = SensorStatus.denied;
      _notify();
    }

    try {
      final stream = FlutterCompass.events;
      if (stream == null) {
        _realCompassStatus = SensorStatus.uncalibrated;
      } else {
        _compassSub = stream.listen(
          (event) {
            final heading = event.heading;
            if (heading == null) return;
            _rawHeading = normalizeDegrees(heading);
            _heading = _filter.filter(_rawHeading);
            _notify();
          },
          onError: (_) {
            _realCompassStatus = SensorStatus.uncalibrated;
            _notify();
          },
        );
      }
    } catch (_) {
      _realCompassStatus = SensorStatus.uncalibrated;
    }
    _notify();
  }

  void _onRealPosition(Position position) {
    _lat = position.latitude;
    _lng = position.longitude;
    _accuracy = position.accuracy;
    _realGpsStatus = position.accuracy > _accuracyLimitM
        ? SensorStatus.noSignal
        : SensorStatus.ok;

    if (_realGpsStatus == SensorStatus.ok) {
      if (_target != null) {
        final point = _directedPoint;
        if (point != null && point.distanceM <= _arrivalM) {
          _handleArrival();
        }
      } else {
        _evaluateGeofence();
      }
    }
    _notify();
  }

  Future<void> _cancelSensorStreams() async {
    await _positionSub?.cancel();
    await _compassSub?.cancel();
    _positionSub = null;
    _compassSub = null;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _ticker?.cancel();
    unawaited(_cancelSensorStreams());
    super.dispose();
  }

  /// Recorrido peatonal de demostración: pasa junto a L, K y C para poder
  /// disparar las geocercas del modo B sin caminar el campus.
  static const List<LocalMeters> _exploreRoute = [
    LocalMeters(0, 0),
    LocalMeters(40, -40),
    LocalMeters(52, -50),
    LocalMeters(96, -62),
    LocalMeters(121.6, -60),
    LocalMeters(110, -20),
    LocalMeters(60, 10),
    LocalMeters(-20, -10),
    LocalMeters(-60, -30),
    LocalMeters(-5, -20),
    LocalMeters(0, 0),
  ];
}
