import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uthmap/data/campus_api.dart';
import 'package:uthmap/data/catalog_repository.dart';

const String _baseUrl = 'https://example.test/api/v1';
const String _deviceId = 'device-123';
const String _fixtureTimestamp = '2026-11-03T04:22:33+00:00';
const String _newTimestamp = '2026-11-10T19:45:00-07:00';

String _fixtureBody() =>
    File('test/fixtures/orionis_sincronizar_v2.json').readAsStringSync();

http.Response _json(String body, {int statusCode = 200}) => http.Response(
  body,
  statusCode,
  headers: const {'content-type': 'application/json'},
);

http.Response _latestUpdate(String? timestamp) =>
    _json(jsonEncode({'success': true, 'message': 'ok', 'data': timestamp}));

CatalogRepository _repository(MockClient client) => CatalogRepository(
  api: CampusApi(
    client: client,
    baseUrl: _baseUrl,
    deviceIdProvider: () async => _deviceId,
  ),
);

/// Envoltura mínima de `/sincronizar_v2` con un solo edificio navegable.
String _singleBuildingPayload(String timestamp) => jsonEncode({
  'success': true,
  'message': 'ok',
  'ultima_actualizacion': timestamp,
  'data': [
    {
      'id': 99,
      'codigo': 'Z',
      'nombre': 'Edificio Z',
      'descripcion': 'Edificio nuevo',
      'dependencias': 'Rectoría, Finanzas',
      'radio_cobertura': 20,
      'foto_url': null,
      'url_video': null,
      'categoria': {'id': 1, 'nombre': 'Académico', 'descripcion': ''},
      'etiquetas': ['nuevo'],
      'coordenada_central': {'latitud': 29.0084, 'longitud': -110.9022},
      'accesos': [
        {
          'id': 1,
          'nombre': 'Acceso Principal',
          'latitud': 29.0084,
          'longitud': -110.9022,
          'tipo_punto': 'ENTRADA_PRINCIPAL',
          'es_principal': true,
        },
      ],
      'perimetro': [],
    },
  ],
});

Future<Map<String, dynamic>?> _storedV2() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(CatalogRepository.catalogV2Key);
  if (raw == null) return null;
  return jsonDecode(raw) as Map<String, dynamic>;
}

void main() {
  test('sin local y remoto OK persiste el payload crudo', () async {
    SharedPreferences.setMockInitialValues({});
    final repository = _repository(
      MockClient((request) async {
        if (request.url.path.endsWith('/ultima_actualizacion')) {
          return _latestUpdate(_fixtureTimestamp);
        }
        return _json(_fixtureBody());
      }),
    );

    final result = await repository.syncRemote();

    expect(result.status, SyncStatus.actualizado);
    expect(result.error, isNull);
    expect(result.catalog, isNotNull);
    expect(result.catalog!.buildings, hasLength(3));
    expect(result.catalog!.skipped, 2);
    expect(result.savedAt, isNotNull);

    final stored = await _storedV2();
    expect(stored, isNotNull);
    expect(stored!['api_timestamp'], _fixtureTimestamp);
    expect(stored['saved_at'], isA<String>());
    expect(DateTime.tryParse(stored['saved_at'] as String), result.savedAt);
    expect((stored['payload'] as Map<String, dynamic>)['data'], hasLength(5));
  });

  test('segundo syncRemote sin cambios hace una sola petición', () async {
    SharedPreferences.setMockInitialValues({});
    final paths = <String>[];
    final repository = _repository(
      MockClient((request) async {
        paths.add(request.url.path);
        if (request.url.path.endsWith('/ultima_actualizacion')) {
          return _latestUpdate(_fixtureTimestamp);
        }
        return _json(_fixtureBody());
      }),
    );

    final first = await repository.syncRemote();
    expect(first.status, SyncStatus.actualizado);
    expect(paths, hasLength(2));

    final requestsBefore = paths.length;
    final second = await repository.syncRemote();

    expect(second.status, SyncStatus.sinCambios);
    expect(second.error, isNull);
    expect(second.catalog, same(first.catalog));
    expect(paths.length - requestsBefore, 1);
    expect(paths.last, endsWith('/ultima_actualizacion'));
  });

  test('timestamp nuevo reemplaza el catálogo por completo', () async {
    SharedPreferences.setMockInitialValues({});
    var remoteTimestamp = _fixtureTimestamp;
    var catalogBody = _fixtureBody();
    final repository = _repository(
      MockClient((request) async {
        if (request.url.path.endsWith('/ultima_actualizacion')) {
          return _latestUpdate(remoteTimestamp);
        }
        return _json(catalogBody);
      }),
    );

    final first = await repository.syncRemote();
    expect(first.catalog!.buildings, hasLength(3));

    remoteTimestamp = _newTimestamp;
    catalogBody = _singleBuildingPayload(_newTimestamp);

    final second = await repository.syncRemote();

    expect(second.status, SyncStatus.actualizado);
    expect(second.catalog!.buildings, hasLength(1));
    expect(second.catalog!.buildings.single.code, 'Z');

    final local = await repository.loadLocal();
    expect(local!.version, _newTimestamp);
    expect(local.buildings, hasLength(1));

    final stored = await _storedV2();
    expect(stored!['api_timestamp'], _newTimestamp);
  });

  test('429 en ultima_actualizacion devuelve offline con el local', () async {
    SharedPreferences.setMockInitialValues({});
    var rateLimited = false;
    final repository = _repository(
      MockClient((request) async {
        if (rateLimited) {
          return http.Response(
            '{"success":false,"data":null,"message":"Too many requests"}',
            429,
            headers: const {'retry-after': '30'},
          );
        }
        if (request.url.path.endsWith('/ultima_actualizacion')) {
          return _latestUpdate(_fixtureTimestamp);
        }
        return _json(_fixtureBody());
      }),
    );

    final first = await repository.syncRemote();
    expect(first.status, SyncStatus.actualizado);
    final localVersion = first.catalog!.version;

    rateLimited = true;
    final result = await repository.syncRemote();

    expect(result.status, SyncStatus.offline);
    expect(result.catalog, isNotNull);
    expect(result.catalog!.version, localVersion);
    expect(result.catalog!.buildings, hasLength(3));
    expect(result.error, isA<RateLimitedException>());
    expect(
      (result.error! as RateLimitedException).retryAfter,
      const Duration(seconds: 30),
    );

    expect(await _storedV2(), isNotNull);
  });

  test('500 en sincronizar_v2 deja el catálogo local intacto', () async {
    SharedPreferences.setMockInitialValues({});
    var newerTimestamp = false;
    final repository = _repository(
      MockClient((request) async {
        if (request.url.path.endsWith('/ultima_actualizacion')) {
          return _latestUpdate(
            newerTimestamp ? _newTimestamp : _fixtureTimestamp,
          );
        }
        if (newerTimestamp) {
          return http.Response('{"success":false,"message":"boom"}', 500);
        }
        return _json(_fixtureBody());
      }),
    );

    final first = await repository.syncRemote();
    expect(first.status, SyncStatus.actualizado);

    final prefs = await SharedPreferences.getInstance();
    final before = prefs.getString(CatalogRepository.catalogV2Key);
    expect(before, isNotNull);

    newerTimestamp = true;
    final result = await repository.syncRemote();

    expect(result.status, SyncStatus.offline);
    expect(result.error, isA<CampusApiException>());
    expect(result.error!.statusCode, 500);
    expect(result.catalog, isNotNull);
    expect(result.catalog!.version, _fixtureTimestamp);
    expect(prefs.getString(CatalogRepository.catalogV2Key), before);

    final local = await repository.loadLocal();
    expect(local!.buildings, hasLength(3));
  });

  test('sin local y 500 devuelve offline sin lanzar', () async {
    SharedPreferences.setMockInitialValues({});
    final repository = _repository(
      MockClient(
        (_) async => http.Response('{"success":false,"message":"boom"}', 500),
      ),
    );

    final result = await repository.syncRemote();

    expect(result.status, SyncStatus.offline);
    expect(result.catalog, isNull);
    expect(result.error, isA<CampusApiException>());
    expect(await _storedV2(), isNull);
  });

  test(
    'clave v2 corrupta: loadLocal no lanza y syncRemote actualiza',
    () async {
      SharedPreferences.setMockInitialValues({
        CatalogRepository.catalogV2Key: '{no json',
      });
      final repository = _repository(
        MockClient((request) async {
          if (request.url.path.endsWith('/ultima_actualizacion')) {
            return _latestUpdate(_fixtureTimestamp);
          }
          return _json(_fixtureBody());
        }),
      );

      expect(await repository.loadLocal(), isNull);

      final result = await repository.syncRemote();

      expect(result.status, SyncStatus.actualizado);
      expect(result.catalog!.buildings, hasLength(3));
      final stored = await _storedV2();
      expect(stored!['api_timestamp'], _fixtureTimestamp);
    },
  );
}
