import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uthmap/data/campus_api.dart';
import 'package:uthmap/data/device_id.dart';

const String _baseUrl = 'https://example.test/api/v1';
const String _deviceId = 'device-123';

CampusApi _api(
  MockClient client, {
  Duration timeout = const Duration(seconds: 10),
  Future<String> Function()? deviceIdProvider,
  Future<void> Function(Duration)? sleep,
}) => CampusApi(
  client: client,
  baseUrl: _baseUrl,
  deviceIdProvider: deviceIdProvider ?? () async => _deviceId,
  timeout: timeout,
  sleep: sleep ?? (_) async {},
);

http.Response _json(
  String body, {
  int statusCode = 200,
  Map<String, String> headers = const {},
}) => http.Response(
  body,
  statusCode,
  headers: {'content-type': 'application/json', ...headers},
);

void main() {
  test('latestUpdate devuelve el timestamp de data', () async {
    final api = _api(
      MockClient(
        (_) async =>
            _json('{"success":true,"data":"2026-11-03T04:22:33+00:00"}'),
      ),
    );

    expect(await api.latestUpdate(), '2026-11-03T04:22:33+00:00');
    await api.close();
  });

  test('latestUpdate devuelve null cuando data es null', () async {
    final api = _api(
      MockClient((_) async => _json('{"success":true,"data":null}')),
    );

    expect(await api.latestUpdate(), isNull);
    await api.close();
  });

  test(
    'ambas rutas envían X-Device-Id y Accept y usan la URL correcta',
    () async {
      final requests = <http.BaseRequest>[];
      var deviceIdCalls = 0;
      final api = _api(
        MockClient((request) async {
          requests.add(request);
          if (request.url.path.endsWith('/ultima_actualizacion')) {
            return _json('{"success":true,"data":null}');
          }
          return _json('{"success":true,"data":[]}');
        }),
        deviceIdProvider: () async {
          deviceIdCalls++;
          return _deviceId;
        },
      );

      await api.latestUpdate();
      await api.fetchCatalog();

      expect(requests, hasLength(2));
      expect(
        requests[0].url.toString(),
        'https://example.test/api/v1/ultima_actualizacion',
      );
      expect(
        requests[1].url.toString(),
        'https://example.test/api/v1/sincronizar_v2',
      );
      for (final request in requests) {
        expect(request.headers['X-Device-Id'], _deviceId);
        expect(request.headers['Accept'], 'application/json');
      }
      expect(deviceIdCalls, 1);
      await api.close();
    },
  );

  test('fetchCatalog mapea la fixture real de /sincronizar_v2', () async {
    final body = File('test/fixtures/orionis_sincronizar_v2.json')
        .readAsStringSync();
    final api = _api(MockClient((_) async => _json(body)));

    final catalog = await api.fetchCatalog();

    expect(catalog.buildings, hasLength(3));
    expect(catalog.skipped, 2);
    await api.close();
  });

  test('429 lanza RateLimitedException con Retry-After', () async {
    final api = _api(
      MockClient(
        (_) async => http.Response(
          '{"success":false,"data":null,"message":"Too many requests"}',
          429,
          headers: const {'retry-after': '30'},
        ),
      ),
    );

    await expectLater(
      api.latestUpdate(),
      throwsA(
        isA<RateLimitedException>().having(
          (error) => error.retryAfter,
          'retryAfter',
          const Duration(seconds: 30),
        ),
      ),
    );
    await api.close();
  });

  group('reintento único en 429', () {
    test(
      '429 con Retry-After de 1 s reintenta una vez y devuelve el payload',
      () async {
        var requests = 0;
        var deviceIdCalls = 0;
        final sleeps = <Duration>[];
        final api = _api(
          MockClient((request) async {
            requests++;
            if (requests == 1) {
              return _json(
                '{"success":false,"data":null,"message":"Too many requests"}',
                statusCode: 429,
                headers: const {'retry-after': '1'},
              );
            }
            return _json('{"success":true,"data":"2026-11-03T04:22:33+00:00"}');
          }),
          deviceIdProvider: () async {
            deviceIdCalls++;
            return _deviceId;
          },
          sleep: (duration) async => sleeps.add(duration),
        );

        expect(await api.latestUpdate(), '2026-11-03T04:22:33+00:00');
        expect(requests, 2);
        expect(sleeps, hasLength(1));
        expect(sleeps.single, const Duration(seconds: 1));
        expect(deviceIdCalls, 1);
        await api.close();
      },
    );

    test(
      '429 dos veces lanza RateLimitedException tras 2 peticiones',
      () async {
        var requests = 0;
        final sleeps = <Duration>[];
        final api = _api(
          MockClient((_) async {
            requests++;
            return _json(
              '{"success":false,"data":null,"message":"Too many requests"}',
              statusCode: 429,
              headers: const {'retry-after': '1'},
            );
          }),
          sleep: (duration) async => sleeps.add(duration),
        );

        await expectLater(
          api.latestUpdate(),
          throwsA(
            isA<RateLimitedException>().having(
              (error) => error.retryAfter,
              'retryAfter',
              isNotNull,
            ),
          ),
        );
        expect(requests, 2);
        expect(sleeps, hasLength(1));
        await api.close();
      },
    );

    test('429 con Retry-After de 60 s no reintenta', () async {
      var requests = 0;
      final sleeps = <Duration>[];
      final api = _api(
        MockClient((_) async {
          requests++;
          return _json(
            '{"success":false,"data":null,"message":"Too many requests"}',
            statusCode: 429,
            headers: const {'retry-after': '60'},
          );
        }),
        sleep: (duration) async => sleeps.add(duration),
      );

      await expectLater(
        api.latestUpdate(),
        throwsA(
          isA<RateLimitedException>().having(
            (error) => error.retryAfter,
            'retryAfter',
            const Duration(seconds: 60),
          ),
        ),
      );
      expect(requests, 1);
      expect(sleeps, isEmpty);
      await api.close();
    });

    test('429 sin Retry-After no reintenta y retryAfter es null', () async {
      var requests = 0;
      final api = _api(
        MockClient((_) async {
          requests++;
          return _json(
            '{"success":false,"data":null,"message":"Too many requests"}',
            statusCode: 429,
          );
        }),
      );

      await expectLater(
        api.latestUpdate(),
        throwsA(
          isA<RateLimitedException>().having(
            (error) => error.retryAfter,
            'retryAfter',
            isNull,
          ),
        ),
      );
      expect(requests, 1);
      await api.close();
    });

    test('200 a la primera hace una sola petición', () async {
      var requests = 0;
      final api = _api(
        MockClient((_) async {
          requests++;
          return _json('{"success":true,"data":null}');
        }),
      );

      expect(await api.latestUpdate(), isNull);
      expect(requests, 1);
      await api.close();
    });

    test('500 no reintenta y lanza CampusApiException', () async {
      var requests = 0;
      final api = _api(
        MockClient((_) async {
          requests++;
          return _json('{"success":false,"message":"boom"}', statusCode: 500);
        }),
      );

      await expectLater(
        api.latestUpdate(),
        throwsA(
          isA<CampusApiException>().having(
            (error) => error.statusCode,
            'statusCode',
            500,
          ),
        ),
      );
      expect(requests, 1);
      await api.close();
    });
  });

  test('500 lanza CampusApiException con statusCode', () async {
    final api = _api(
      MockClient(
        (_) async => http.Response('{"success":false,"message":"boom"}', 500),
      ),
    );

    await expectLater(
      api.latestUpdate(),
      throwsA(
        isA<CampusApiException>().having(
          (error) => error.statusCode,
          'statusCode',
          500,
        ),
      ),
    );
    await api.close();
  });

  test('cuerpo no JSON lanza CampusApiException, no FormatException', () async {
    final api = _api(MockClient((_) async => _json('no es json')));

    await expectLater(
      api.latestUpdate(),
      throwsA(allOf(isA<CampusApiException>(), isNot(isA<FormatException>()))),
    );
    await api.close();
  });

  test('success:false lanza CampusApiException', () async {
    final api = _api(
      MockClient((_) async => _json('{"success":false,"data":[]}')),
    );

    await expectLater(api.fetchCatalog(), throwsA(isA<CampusApiException>()));
    await api.close();
  });

  test(
    'timeout vencido lanza CampusApiException con mensaje timeout',
    () async {
      final api = _api(
        MockClient((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 200));
          return _json('{"success":true,"data":null}');
        }),
        timeout: const Duration(milliseconds: 50),
      );

      await expectLater(
        api.latestUpdate(),
        throwsA(
          isA<CampusApiException>().having(
            (error) => error.message,
            'message',
            contains('timeout'),
          ),
        ),
      );
      await api.close();
    },
  );

  group('ensureDeviceId', () {
    test('genera, persiste y reutiliza el UUID', () async {
      SharedPreferences.setMockInitialValues({});

      final first = await ensureDeviceId();
      expect(first, isNotEmpty);
      expect(
        first,
        matches(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          ),
        ),
      );

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(deviceIdKey), first);
      expect(await ensureDeviceId(), first);
    });

    test('con un valor guardado no genera otro', () async {
      SharedPreferences.setMockInitialValues({deviceIdKey: 'id-existente'});

      expect(await ensureDeviceId(), 'id-existente');
    });
  });
}
