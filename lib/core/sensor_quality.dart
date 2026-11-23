/// Calidad de sensores sin dependencias de Flutter ni de plugins.
///
/// Contiene tres piezas puras y testeables:
/// - [FixGate]: descarta fixes imprecisos, viejos o con saltos imposibles.
/// - [applyDeclinationDeg]: corrige el rumbo con la declinación magnética.
/// - [SensorLog]: log acotado en memoria para depurar en campo.
library;

import 'geo.dart';

/// Motivo por el que la puerta descarta un fix.
enum FixRejection { tooImprecise, stale, implausibleJump }

/// Lectura de posición tal como llega del GPS.
class FixSample {
  const FixSample({
    required this.lat,
    required this.lng,
    required this.accuracyM,
    required this.timestamp,
  });

  final double lat;
  final double lng;
  final double accuracyM;
  final DateTime timestamp;
}

/// Resultado de evaluar un fix con [FixGate].
class FixVerdict {
  const FixVerdict.accepted({required this.distanceFromLastM})
    : rejection = null;

  const FixVerdict.rejected(FixRejection this.rejection)
    : distanceFromLastM = null;

  /// `null` si el fix se acepta.
  final FixRejection? rejection;

  /// Distancia al último fix aceptado; `null` si se rechaza o no hay previo.
  final double? distanceFromLastM;

  bool get accepted => rejection == null;
}

/// Puerta de calidad de fixes.
///
/// El orden de descarte es: precisión, antigüedad y salto. Un fix rechazado
/// nunca actualiza la referencia interna, así que un fix malo aislado no
/// envenena las evaluaciones siguientes.
class FixGate {
  FixGate({
    this.maxAccuracyM = 30,
    this.maxAge = const Duration(seconds: 5),
    this.minIntervalForJump = const Duration(seconds: 2),
    this.maxJumpM = 60,
  });

  /// Precisión máxima aceptada en metros (el límite entra: 30 se acepta).
  final double maxAccuracyM;

  /// Antigüedad máxima respecto de `now` (el límite entra: 5 s se acepta).
  final Duration maxAge;

  /// Intervalo mínimo entre fixes para tolerar un salto mayor que [maxJumpM].
  final Duration minIntervalForJump;

  /// Salto máximo tolerado dentro de [minIntervalForJump].
  final double maxJumpM;

  FixSample? _lastAccepted;

  /// Evalúa [fix]. [now] fija el reloj para detectar fixes viejos; una marca de
  /// tiempo futura cuenta como reciente.
  FixVerdict evaluate(FixSample fix, {required DateTime now}) {
    if (fix.accuracyM > maxAccuracyM) {
      return const FixVerdict.rejected(FixRejection.tooImprecise);
    }
    if (now.difference(fix.timestamp) > maxAge) {
      return const FixVerdict.rejected(FixRejection.stale);
    }

    final last = _lastAccepted;
    if (last == null) {
      _lastAccepted = fix;
      return const FixVerdict.accepted(distanceFromLastM: null);
    }

    final distance = haversineM(last.lat, last.lng, fix.lat, fix.lng);
    final elapsed = fix.timestamp.difference(last.timestamp);
    if (distance > maxJumpM && elapsed < minIntervalForJump) {
      return const FixVerdict.rejected(FixRejection.implausibleJump);
    }

    _lastAccepted = fix;
    return FixVerdict.accepted(distanceFromLastM: distance);
  }

  /// Olvida el último fix aceptado.
  void reset() => _lastAccepted = null;
}

/// Suma la declinación y normaliza a [0, 360).
double applyDeclinationDeg(double headingDeg, double declinationDeg) =>
    normalizeDegrees(headingDeg + declinationDeg);

/// Entrada del log de depuración de sensores.
class SensorLogEntry {
  const SensorLogEntry({required this.at, required this.event, this.data});

  final DateTime at;
  final String event;
  final String? data;

  /// `HH:mm:ss · evento · dato` (sin el separador final si [data] es null).
  String format() {
    final time =
        '${_twoDigits(at.hour)}:${_twoDigits(at.minute)}:'
        '${_twoDigits(at.second)}';
    final payload = data;
    return payload == null ? '$time · $event' : '$time · $event · $payload';
  }
}

/// Log acotado en memoria: conserva las últimas [capacity] entradas.
class SensorLog {
  SensorLog({this.capacity = 100, DateTime Function()? clock})
    : assert(capacity > 0, 'capacity debe ser positiva'),
      _clock = clock ?? DateTime.now;

  final int capacity;
  final DateTime Function() _clock;
  final List<SensorLogEntry> _entries = <SensorLogEntry>[];

  /// Registra [event] con un [data] opcional y la hora del reloj inyectado.
  void add(String event, [String? data]) {
    _entries.add(SensorLogEntry(at: _clock(), event: event, data: data));
    while (_entries.length > capacity) {
      _entries.removeAt(0);
    }
  }

  /// Del más antiguo al más reciente; no modificable.
  List<SensorLogEntry> get entries => List.unmodifiable(_entries);

  /// [SensorLogEntry.format] de cada entrada, en el mismo orden.
  List<String> get lines =>
      List.unmodifiable(_entries.map((entry) => entry.format()));

  void clear() => _entries.clear();
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');
