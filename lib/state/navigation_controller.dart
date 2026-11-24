import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';

import '../core/geo.dart';
import '../core/geofence.dart';
import '../core/sensor_quality.dart';
import '../data/models.dart';
import '../data/sensor_prefs.dart';
import '../state/nav_state.dart';

enum GpsSimulation { ok, denied, disabled, noSignal }

/// Motor de navegación del prototipo. Los cálculos viven en core/ y aquí solo
/// se orquesta el estado, la simulación y (opcionalmente) los sensores reales.
class NavigationController extends ChangeNotifier {
  NavigationController({
    required this.catalog,
    SensorPrefs? sensorPrefs,
    DateTime Function()? clock,
  }) : // Un parámetro nombrado no puede empezar por `_`, así que no se puede
       // usar el formal inicializador que sugiere el lint.
       // ignore: prefer_initializing_formals
       _sensorPrefs = sensorPrefs,
       _clock = clock ?? DateTime.now {
    _reset(notify: false);
  }

  final Catalog catalog;

  /// `null` en tests: no se lee ni se escribe nada en disco.
  final SensorPrefs? _sensorPrefs;

  /// Reloj inyectable para el descarte de fixes y las marcas del log.
  final DateTime Function() _clock;

  static const Duration _tickDuration = Duration(milliseconds: 300);
  static const double _stepM = 3;
  static const double _accuracyLimitM = 30;
  static const double _compassAccuracyLimitDeg = 15;

  /// Filtro de calidad de fixes: descarta imprecisos, viejos y saltos.
  final FixGate _gate = FixGate();

  late final SensorLog _log = SensorLog(capacity: _logCapacity, clock: _clock);

  static const int _logCapacity = 40;

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

  /// Lectura cruda del magnetómetro (sin declinación). La simulación la
  /// mantiene igual a `_rawHeading`.
  double _rawCompassDeg = 278;
  double _declinationDeg = 0;
  double? _compassAccuracyDeg;
  bool _settingsLoaded = false;

  bool _realSensors = false;

  /// `true` mientras la próxima lectura del magnetómetro deba fijar el rumbo
  /// directamente: al activar los sensores reales el filtro no debe arrastrar
  /// el valor sembrado de la demo (278°).
  bool _compassSeedPending = false;

  SensorStatus _realGpsStatus = SensorStatus.ok;
  SensorStatus _realCompassStatus = SensorStatus.ok;
  int _consecutiveRejections = 0;
  StreamSubscription<Position>? _positionSub;
  StreamSubscription<CompassEvent>? _compassSub;
  bool _disposed = false;

  /// La pantalla de navegación lo usa para abrir la ficha al llegar.
  ValueChanged<Building>? onArrival;

  List<Building> get buildings => catalog.buildings;

  GeoPoint get position => GeoPoint(_lat, _lng);

  /// Origen de la proyección: el centro del catálogo si la API lo trae
  /// (D-26); si no, el origen global del campus.
  GeoPoint get origin => catalog.originLat != null && catalog.originLng != null
      ? GeoPoint(catalog.originLat!, catalog.originLng!)
      : const GeoPoint(campusOriginLat, campusOriginLng);

  double get latitude => _lat;

  double get longitude => _lng;

  double get rawHeading => _rawHeading;

  double get heading => _heading;

  double? get accuracyM => _accuracy;

  bool get walking => _walking;

  bool get realSensors => _realSensors;

  GpsSimulation get gpsSimulation => _gpsSimulation;

  bool get compassUncalibrated => _compassUncalibrated;

  /// Declinación magnética aplicada al rumbo real, en grados.
  double get declinationDeg => _declinationDeg;

  /// Exactitud reportada por la brújula, en grados (`null` si no la informa).
  double? get compassAccuracyDeg => _compassAccuracyDeg;

  /// Últimas entradas del log de sensores (máximo 40), de la más vieja a la
  /// más reciente.
  List<String> get sensorLogLines => _log.lines;

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
      'Señal GPS débil (más de ${_accuracyLimitM.toInt()} m de precisión). La geocerca está en pausa.',
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
    _lat = origin.lat;
    _lng = origin.lng;
    _rawCompassDeg = 278;
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
    _rawCompassDeg = normalizeDegrees(degrees);
    _rawHeading = _rawCompassDeg;
    _heading = _filter.filter(_rawHeading);
    _notify();
  }

  /// Carga la calibración persistida. Idempotente: solo lee la primera vez.
  Future<void> loadSettings() async {
    if (_settingsLoaded) return;
    _settingsLoaded = true;

    final prefs = _sensorPrefs;
    if (prefs == null) return;

    try {
      final stored = await prefs.loadDeclinationDeg();
      _applyDeclination(stored);
      _log.add('declinación', '${_declinationDeg.toStringAsFixed(1)}°');
      _notify();
    } catch (_) {
      // Sin almacenamiento disponible se mantiene la declinación actual.
    }
  }

  /// Fija la declinación, la persiste y recalcula el rumbo corregido.
  Future<void> setDeclinationDeg(double value) async {
    _applyDeclination(value);
    _log.add('declinación', '${_declinationDeg.toStringAsFixed(1)}°');
    _notify();

    final prefs = _sensorPrefs;
    if (prefs == null) return;
    try {
      await prefs.saveDeclinationDeg(_declinationDeg);
    } catch (_) {
      // Un fallo de persistencia no rompe la navegación.
    }
  }

  /// Aplica [value] recortado a [-30, 30] sobre la última lectura del
  /// magnetómetro y reinicia el filtro para que el panel no arrastre el valor
  /// anterior.
  void _applyDeclination(double value) {
    _declinationDeg = _clampDeclination(value);
    _rawHeading = applyDeclinationDeg(_rawCompassDeg, _declinationDeg);
    _heading = _rawHeading;
    _filter.reset(_rawHeading);
  }

  static double _clampDeclination(double value) =>
      value.clamp(-30.0, 30.0).toDouble();

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
      final arrival = arrivalRadiusM(_target!.coverageRadiusM);
      if (point.distanceM <= arrival) {
        _handleArrival();
        return;
      }
      _moveToward(point.point, _stepM);
      final updated = _directedPoint;
      if (updated != null && updated.distanceM <= arrival) {
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
    _arrivalHaptic();
    final building = _target;
    if (building != null && !_arrivalNotified) {
      _arrivalNotified = true;
      onArrival?.call(building);
    }
    _notify();
  }

  /// Aviso de llegada del Modo A: doble vibración ligera y silenciosa, sin
  /// sonido. El aviso fuerte de [_alert] queda reservado a la geocerca (Modo B).
  void _arrivalHaptic() {
    unawaited(HapticFeedback.lightImpact());
    Timer(const Duration(milliseconds: 120), () {
      if (_disposed) return;
      unawaited(HapticFeedback.lightImpact());
    });
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
    final point = campusPoint(waypoint.east, waypoint.north, origin: origin);
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
    _compassSeedPending = enabled;
    _realGpsStatus = SensorStatus.ok;
    _realCompassStatus = SensorStatus.ok;
    _compassAccuracyDeg = null;
    _consecutiveRejections = 0;

    if (!enabled) {
      _log.add('sensores off');
      _notify();
      return;
    }

    _gate.reset();
    _log.add('sensores on');
    _notify();

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _realGpsStatus = SensorStatus.disabled;
        _log.add('permiso', SensorStatus.disabled.name);
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
        _log.add('permiso', SensorStatus.denied.name);
        _notify();
        return;
      }

      _log.add('permiso', permission.name);
      _listenPosition();
      _realGpsStatus = SensorStatus.ok;
      _notify();
    } catch (_) {
      _realGpsStatus = SensorStatus.denied;
      _log.add('permiso', SensorStatus.denied.name);
      _notify();
    }

    _listenCompass();
    _notify();
  }

  /// Cancela los streams reales sin cambiar de modo (ahorro de batería).
  Future<void> pauseSensors() async {
    if (!_realSensors) return;
    await _cancelSensorStreams();
    _log.add('sensores en pausa');
    _notify();
  }

  /// Re-suscribe los streams si el modo real sigue activo.
  Future<void> resumeSensors() async {
    if (!_realSensors || _disposed) return;
    if (_positionSub != null || _compassSub != null) return;
    _listenPosition();
    _listenCompass();
    _log.add('sensores en marcha');
    _notify();
  }

  void _listenPosition() {
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
  }

  void _listenCompass() {
    try {
      final stream = FlutterCompass.events;
      if (stream == null) {
        _realCompassStatus = SensorStatus.uncalibrated;
        _log.add('brújula', 'sin sensor');
        return;
      }
      _compassSub = stream.listen(
        _onCompassEvent,
        onError: (_) {
          _realCompassStatus = SensorStatus.uncalibrated;
          _log.add('brújula', 'error');
          _notify();
        },
      );
    } catch (_) {
      _realCompassStatus = SensorStatus.uncalibrated;
      _log.add('brújula', 'error');
    }
  }

  void _onRealPosition(Position position) {
    _ingestFix(
      lat: position.latitude,
      lng: position.longitude,
      accuracyM: position.accuracy,
      timestamp: position.timestamp,
    );
  }

  /// Único camino de entrada de un fix: gate → estado → llegada/geocerca.
  void _ingestFix({
    required double lat,
    required double lng,
    required double accuracyM,
    required DateTime timestamp,
  }) {
    final verdict = _gate.evaluate(
      FixSample(lat: lat, lng: lng, accuracyM: accuracyM, timestamp: timestamp),
      now: _clock(),
    );

    if (!verdict.accepted) {
      _consecutiveRejections++;
      _log.add('fix rechazado', verdict.rejection!.name);
      if (_consecutiveRejections >= 3) {
        _realGpsStatus = SensorStatus.noSignal;
      }
      _notify();
      return;
    }

    _lat = lat;
    _lng = lng;
    _accuracy = accuracyM;
    _realGpsStatus = SensorStatus.ok;
    _consecutiveRejections = 0;
    final distance = verdict.distanceFromLastM;
    _log.add(
      'fix ok',
      distance == null ? 'd=primero' : 'd=${distance.toStringAsFixed(1)}m',
    );

    if (_target != null) {
      final point = _directedPoint;
      if (point != null &&
          point.distanceM <= arrivalRadiusM(_target!.coverageRadiusM)) {
        _handleArrival();
      }
    } else {
      _evaluateGeofence();
    }
    _notify();
  }

  /// Un evento de brújula: declinación → filtro → exactitud.
  void _onCompassEvent(CompassEvent event) {
    _ingestCompass(heading: event.heading, accuracy: event.accuracy);
  }

  void _ingestCompass({required double? heading, double? accuracy}) {
    if (accuracy != null) {
      final previous = _realCompassStatus;
      _compassAccuracyDeg = accuracy;
      _realCompassStatus = accuracy > _compassAccuracyLimitDeg
          ? SensorStatus.uncalibrated
          : SensorStatus.ok;
      if (_realCompassStatus != previous) {
        _log.add('brújula', '±${accuracy.toStringAsFixed(1)}°');
      }
    }

    if (heading == null) {
      _notify();
      return;
    }

    _rawCompassDeg = normalizeDegrees(heading);
    _rawHeading = applyDeclinationDeg(_rawCompassDeg, _declinationDeg);
    if (_compassSeedPending) {
      // Arranque limpio: la primera lectura real fija el rumbo sin mezclarse
      // con el 278° de la demo.
      _compassSeedPending = false;
      _filter.reset(_rawHeading);
      _heading = _rawHeading;
      _log.add('brújula', 'arranque ${_heading.toStringAsFixed(0)}°');
    } else {
      _heading = _filter.filter(_rawHeading);
    }
    _notify();
  }

  /// Inyecta un fix por el mismo camino que un `Position` real.
  @visibleForTesting
  void debugIngestFix({
    required double lat,
    required double lng,
    required double accuracyM,
    required DateTime timestamp,
  }) => _ingestFix(
    lat: lat,
    lng: lng,
    accuracyM: accuracyM,
    timestamp: timestamp,
  );

  /// Inyecta una lectura de brújula por el mismo camino que un evento real.
  @visibleForTesting
  void debugIngestCompass({required double heading, double? accuracy}) =>
      _ingestCompass(heading: heading, accuracy: accuracy);

  /// Activa el modo real sin tocar plugins (solo para tests).
  @visibleForTesting
  void debugUseRealSensors() {
    _realSensors = true;
    _compassSeedPending = true;
    _gate.reset();
    _consecutiveRejections = 0;
    _realGpsStatus = SensorStatus.ok;
    _realCompassStatus = SensorStatus.ok;
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
