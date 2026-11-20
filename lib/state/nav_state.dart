import '../data/models.dart';

enum NavMode { explore, directed }

enum SensorStatus { ok, denied, disabled, noSignal, uncalibrated }

/// Contrato inmutable entre el motor y la UI (documento de arquitectura §4.3).
class NavState {
  const NavState({
    required this.mode,
    required this.distanceM,
    required this.needleDeg,
    required this.bearingDeg,
    required this.headingDeg,
    required this.quadrant,
    required this.target,
    required this.nearby,
    required this.arrived,
    required this.gps,
    required this.compass,
    required this.accuracyM,
  });

  final NavMode mode;
  final double? distanceM;
  final double? needleDeg;
  final double? bearingDeg;
  final double? headingDeg;
  final String? quadrant;
  final Building? target;
  final Building? nearby;
  final bool arrived;
  final SensorStatus gps;
  final SensorStatus compass;
  final double? accuracyM;
}
