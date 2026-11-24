import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'catalog_v2_mapper.dart';
import 'device_id.dart';
import 'models.dart';

/// Base de Orionis; configurable con `--dart-define=ORIONIS_BASE_URL=...`.
const String defaultOrionisBaseUrl = String.fromEnvironment(
  'ORIONIS_BASE_URL',
  defaultValue: 'https://orionis.osoware.com/api/v1',
);

/// Tiempo máximo por petición (`docs/01-api-contract.md` §"Errores a manejar").
const Duration defaultCampusApiTimeout = Duration(seconds: 10);

/// Espera máxima que se acepta respetar con un reintento único tras un 429.
const Duration _maxRateLimitRetry = Duration(seconds: 2);

/// Fallo de red, HTTP o de formato; el consumidor nunca ve otra excepción.
class CampusApiException implements Exception {
  const CampusApiException({this.statusCode, required this.message});

  /// Código HTTP cuando el fallo proviene de una respuesta.
  final int? statusCode;

  /// Descripción legible; `'timeout'` cuando venció el plazo de la petición.
  final String message;

  @override
  String toString() =>
      'CampusApiException(statusCode: $statusCode, message: $message)';
}

/// 429: cuota agotada por dispositivo; respetar [retryAfter] antes de reintentar.
class RateLimitedException extends CampusApiException {
  const RateLimitedException({required super.message, this.retryAfter})
    : super(statusCode: 429);

  /// Valor leído de `Retry-After` (segundos), o `null` si no era numérico.
  final Duration? retryAfter;

  @override
  String toString() =>
      'RateLimitedException(retryAfter: $retryAfter, message: $message)';
}

/// Cliente HTTP de solo lectura contra Orionis.
///
/// Todas las peticiones llevan `Accept: application/json` y
/// `X-Device-Id: <uuid>`; el UUID se resuelve una sola vez por instancia.
class CampusApi {
  CampusApi({
    http.Client? client,
    String baseUrl = defaultOrionisBaseUrl,
    Future<String> Function()? deviceIdProvider,
    this.timeout = defaultCampusApiTimeout,
    Future<void> Function(Duration)? sleep,
  }) : _client = client ?? http.Client(),
       _baseUrl = baseUrl.endsWith('/')
           ? baseUrl.substring(0, baseUrl.length - 1)
           : baseUrl,
       _deviceIdProvider = deviceIdProvider ?? ensureDeviceId,
       _sleep = sleep ?? Future<void>.delayed;

  final http.Client _client;
  final String _baseUrl;
  final Future<String> Function() _deviceIdProvider;
  final Future<void> Function(Duration) _sleep;

  /// Plazo máximo por petición; inyectable en tests.
  final Duration timeout;

  Future<String>? _deviceIdFuture;

  /// `GET /ultima_actualizacion` -> timestamp ISO 8601 o `null`.
  Future<String?> latestUpdate() async {
    final json = await _getJson('ultima_actualizacion');
    final data = json['data'];
    if (data == null) return null;
    if (data is String) return data;
    throw const CampusApiException(
      message: '/ultima_actualizacion: data no es una cadena',
    );
  }

  /// `GET /sincronizar_v2` -> envoltura cruda ya validada (`success == true`
  /// y `data` es una lista). El consumidor decide cuándo mapearla.
  Future<Map<String, dynamic>> fetchCatalogPayload() async {
    final json = await _getJson('sincronizar_v2');
    if (json['data'] is! List) {
      throw const CampusApiException(
        message: 'catálogo inválido: /sincronizar_v2 data no es una lista',
      );
    }
    return json;
  }

  /// `GET /sincronizar_v2` -> catálogo mapeado a los modelos locales.
  Future<Catalog> fetchCatalog() async {
    final json = await fetchCatalogPayload();
    try {
      return catalogFromSincronizarV2(json);
    } on CampusApiException {
      rethrow;
    } catch (error) {
      throw CampusApiException(message: 'catálogo inválido: $error');
    }
  }

  /// Cierra el cliente HTTP subyacente.
  Future<void> close() async => _client.close();

  Uri _uri(String path) => Uri.parse('$_baseUrl/$path');

  Future<String> _requireDeviceId() => _deviceIdFuture ??= _deviceIdProvider();

  Future<Map<String, dynamic>> _getJson(String path) async {
    final deviceId = await _requireDeviceId();

    var attempt = 0;
    while (true) {
      attempt++;
      final response = await _get(path, deviceId);

      if (response.statusCode == 429) {
        final retryAfter = _parseRetryAfter(response.headers);
        if (attempt == 1 &&
            retryAfter != null &&
            retryAfter <= _maxRateLimitRetry) {
          await _sleep(retryAfter);
          continue;
        }
        throw RateLimitedException(
          message: _messageFromBody(response.body) ?? 'cuota agotada',
          retryAfter: retryAfter,
        );
      }
      if (response.statusCode != 200) {
        throw CampusApiException(
          statusCode: response.statusCode,
          message:
              _messageFromBody(response.body) ?? 'HTTP ${response.statusCode}',
        );
      }

      return _decodeEnvelope(response.body);
    }
  }

  Future<http.Response> _get(String path, String deviceId) async {
    try {
      return await _client
          .get(
            _uri(path),
            headers: {'Accept': 'application/json', 'X-Device-Id': deviceId},
          )
          .timeout(timeout);
    } on TimeoutException {
      throw const CampusApiException(message: 'timeout');
    } catch (error) {
      throw CampusApiException(message: 'fallo de red: $error');
    }
  }

  Map<String, dynamic> _decodeEnvelope(String body) {
    Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException catch (error) {
      throw CampusApiException(message: 'respuesta no es JSON: $error');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const CampusApiException(message: 'respuesta no es un objeto JSON');
    }
    if (decoded['success'] != true) {
      final message = decoded['message'];
      throw CampusApiException(
        message: message is String && message.trim().isNotEmpty
            ? message
            : 'success distinto de true',
      );
    }
    return decoded;
  }

  String? _messageFromBody(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final message = decoded['message'];
        if (message is String && message.trim().isNotEmpty) return message;
      }
    } catch (_) {
      // Cuerpo no JSON: se usa el mensaje por defecto.
    }
    return null;
  }

  Duration? _parseRetryAfter(Map<String, String> headers) {
    final raw = headers['retry-after'] ?? headers['Retry-After'];
    if (raw == null) return null;
    final seconds = int.tryParse(raw.trim());
    return seconds == null ? null : Duration(seconds: seconds);
  }
}
