import 'package:flutter_test/flutter_test.dart';
import 'package:uthmap/core/geo.dart';
import 'package:uthmap/core/sensor_quality.dart';

const double _lat = campusOriginLat;
const double _lng = campusOriginLng;

/// Fix situado [meters] al norte del origen del campus (misma esfera que
/// [haversineM], así la distancia esperada es exactamente [meters]).
FixSample _fixNorth(double meters, DateTime at, {double accuracyM = 5}) =>
    FixSample(
      lat: _lat + toDegrees(meters / earthRadiusM),
      lng: _lng,
      accuracyM: accuracyM,
      timestamp: at,
    );

double _distance(FixSample a, FixSample b) =>
    haversineM(a.lat, a.lng, b.lat, b.lng);

void main() {
  final t0 = DateTime(2026, 3, 10, 12, 0, 0);

  group('FixGate · precisión', () {
    test('30 m de precisión se acepta', () {
      final gate = FixGate();
      final fix = _fixNorth(0, t0, accuracyM: 30);

      final verdict = gate.evaluate(fix, now: t0);

      expect(verdict.accepted, isTrue);
      expect(verdict.rejection, isNull);
    });

    test('30.1 m de precisión se rechaza por tooImprecise', () {
      final gate = FixGate();
      final fix = _fixNorth(0, t0, accuracyM: 30.1);

      final verdict = gate.evaluate(fix, now: t0);

      expect(verdict.accepted, isFalse);
      expect(verdict.rejection, FixRejection.tooImprecise);
      expect(verdict.distanceFromLastM, isNull);
    });
  });

  group('FixGate · antigüedad', () {
    test('un fix de hace exactamente 5 s se acepta', () {
      final gate = FixGate();
      final fix = _fixNorth(0, t0.subtract(const Duration(seconds: 5)));

      expect(gate.evaluate(fix, now: t0).accepted, isTrue);
    });

    test('un fix de hace 5 s y 1 ms se rechaza por stale', () {
      final gate = FixGate();
      final fix = _fixNorth(
        0,
        t0.subtract(const Duration(seconds: 5, milliseconds: 1)),
      );

      final verdict = gate.evaluate(fix, now: t0);

      expect(verdict.rejection, FixRejection.stale);
      expect(verdict.distanceFromLastM, isNull);
    });

    test('una marca de tiempo futura (desfase de reloj) se acepta', () {
      final gate = FixGate();
      final fix = _fixNorth(0, t0.add(const Duration(seconds: 3)));

      expect(gate.evaluate(fix, now: t0).accepted, isTrue);
    });
  });

  group('FixGate · saltos', () {
    test('el primer fix se acepta sin distancia previa', () {
      final gate = FixGate();
      final verdict = gate.evaluate(_fixNorth(0, t0), now: t0);

      expect(verdict.accepted, isTrue);
      expect(verdict.distanceFromLastM, isNull);
    });

    test('salto de 100 m en 1 s se rechaza por implausibleJump', () {
      final gate = FixGate();
      final first = _fixNorth(0, t0);
      final second = _fixNorth(100, t0.add(const Duration(seconds: 1)));
      gate.evaluate(first, now: t0);

      final verdict = gate.evaluate(second, now: second.timestamp);

      expect(_distance(first, second), greaterThan(60));
      expect(verdict.rejection, FixRejection.implausibleJump);
      expect(verdict.distanceFromLastM, isNull);
    });

    test('el mismo salto de 100 m en 5 s se acepta', () {
      final gate = FixGate();
      final first = _fixNorth(0, t0);
      final second = _fixNorth(100, t0.add(const Duration(seconds: 5)));
      gate.evaluate(first, now: t0);

      final verdict = gate.evaluate(second, now: second.timestamp);

      expect(verdict.accepted, isTrue);
      expect(
        verdict.distanceFromLastM,
        closeTo(_distance(first, second), 0.01),
      );
      expect(verdict.distanceFromLastM, closeTo(100, 0.01));
    });

    test('salto de 40 m en 1 s se acepta', () {
      final gate = FixGate();
      final first = _fixNorth(0, t0);
      final second = _fixNorth(40, t0.add(const Duration(seconds: 1)));
      gate.evaluate(first, now: t0);

      final verdict = gate.evaluate(second, now: second.timestamp);

      expect(verdict.accepted, isTrue);
      expect(
        verdict.distanceFromLastM,
        closeTo(_distance(first, second), 0.01),
      );
      expect(verdict.distanceFromLastM, closeTo(40, 0.01));
    });
  });

  group('FixGate · referencia interna', () {
    test('un rechazo no mueve el último fix aceptado', () {
      final gate = FixGate();
      final a = _fixNorth(0, t0);
      final bad = _fixNorth(100, t0.add(const Duration(seconds: 1)));
      final c = _fixNorth(10, t0.add(const Duration(seconds: 10)));

      expect(gate.evaluate(a, now: t0).accepted, isTrue);
      expect(
        gate.evaluate(bad, now: bad.timestamp).rejection,
        FixRejection.implausibleJump,
      );

      final verdict = gate.evaluate(c, now: c.timestamp);

      expect(verdict.accepted, isTrue);
      expect(verdict.distanceFromLastM, closeTo(_distance(a, c), 0.01));
      expect(verdict.distanceFromLastM, closeTo(10, 0.01));
    });

    test('reset() olvida el previo y el siguiente fix se acepta', () {
      final gate = FixGate();
      final a = _fixNorth(0, t0);
      final jump = _fixNorth(100, t0.add(const Duration(seconds: 1)));
      gate.evaluate(a, now: t0);

      expect(
        gate.evaluate(jump, now: jump.timestamp).rejection,
        FixRejection.implausibleJump,
      );

      gate.reset();
      final verdict = gate.evaluate(jump, now: jump.timestamp);

      expect(verdict.accepted, isTrue);
      expect(verdict.distanceFromLastM, isNull);
    });
  });

  group('applyDeclinationDeg', () {
    test('normaliza a [0, 360)', () {
      expect(applyDeclinationDeg(359, 5), closeTo(4, 1e-9));
      expect(applyDeclinationDeg(5, -10), closeTo(355, 1e-9));
      expect(applyDeclinationDeg(0, 0), closeTo(0, 1e-9));
    });
  });

  group('SensorLog', () {
    test('conserva las últimas capacity entradas en orden', () {
      var tick = 0;
      final log = SensorLog(
        capacity: 3,
        clock: () => DateTime(2026, 1, 2, 3, 4, 5 + tick++),
      );

      for (final event in ['e1', 'e2', 'e3', 'e4']) {
        log.add(event);
      }

      expect(log.entries, hasLength(3));
      expect(log.entries.map((entry) => entry.event), ['e2', 'e3', 'e4']);
      expect(log.lines, ['03:04:06 · e2', '03:04:07 · e3', '03:04:08 · e4']);
    });

    test('format() incluye el dato solo cuando existe', () {
      final withData = SensorLogEntry(
        at: DateTime(2026, 1, 2, 9, 5, 7),
        event: 'fix',
        data: 'dist=12m',
      );
      final withoutData = SensorLogEntry(
        at: DateTime(2026, 1, 2, 9, 5, 7),
        event: 'fix',
      );

      expect(withData.format(), '09:05:07 · fix · dist=12m');
      expect(withoutData.format(), '09:05:07 · fix');
    });

    test('entries y lines son no modificables', () {
      final log = SensorLog(clock: () => t0);
      log.add('fix');

      expect(
        () => log.entries.add(SensorLogEntry(at: t0, event: 'otro')),
        throwsUnsupportedError,
      );
      expect(() => log.lines.add('otra'), throwsUnsupportedError);
    });

    test('clear() vacía el log', () {
      final log = SensorLog(clock: () => t0);
      log.add('fix');
      log.add('heading');

      expect(log.entries, isNotEmpty);
      log.clear();

      expect(log.entries, isEmpty);
      expect(log.lines, isEmpty);
    });
  });
}
