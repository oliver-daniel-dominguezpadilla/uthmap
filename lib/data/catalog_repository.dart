import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'campus_api.dart';
import 'catalog_v2_mapper.dart';
import 'models.dart';

/// Resultado de una sincronización contra Orionis.
enum SyncStatus {
  /// Se descargó y persistió un catálogo nuevo.
  actualizado,

  /// El timestamp remoto coincide con el guardado: no se volvió a descargar.
  sinCambios,

  /// Sin red, 429, error HTTP o payload inválido: se conserva lo local.
  offline,
}

/// Desenlace de [CatalogRepository.syncRemote]; nunca se lanza al consumidor.
class SyncResult {
  const SyncResult({
    required this.catalog,
    required this.status,
    this.error,
    this.savedAt,
  });

  /// `null` solo si no había catálogo local y la sincronización falló.
  final Catalog? catalog;

  final SyncStatus status;

  /// Informativo (la UI decide cómo mostrarlo); no se lanza.
  final CampusApiException? error;

  /// Momento en que se guardó el catálogo devuelto.
  final DateTime? savedAt;
}

/// Catálogo del dispositivo: payload crudo de `/sincronizar_v2` persistido en
/// clave-valor, más el catálogo legacy del prototipo (assets locales).
class CatalogRepository {
  CatalogRepository({CampusApi? api}) : _api = api ?? CampusApi();

  static const String catalogKey = 'uthmap.catalog.v1';
  static const String syncedAtKey = 'uthmap.syncedAt.v1';

  /// Payload crudo de `/sincronizar_v2` (D-15). Una sola clave: el reemplazo
  /// del catálogo completo es un único `setString`.
  static const String catalogV2Key = 'uthmap.catalogV2.v1';
  static const String assetPath = 'assets/data/edificios.json';

  final CampusApi _api;
  Catalog? _memoryCatalog;

  /// Catálogo local: primero el payload v2, después el legacy; nunca lanza.
  Future<Catalog?> loadLocal() async {
    final cached = _memoryCatalog;
    if (cached != null) return cached;

    final prefs = await SharedPreferences.getInstance();

    final stored = _decodeStoredV2(prefs.getString(catalogV2Key));
    if (stored != null) {
      try {
        final catalog = catalogFromSincronizarV2(stored.payload);
        _memoryCatalog = catalog;
        return catalog;
      } catch (_) {
        // Payload corrupto: se intenta el catálogo legacy.
      }
    }

    final raw = prefs.getString(catalogKey);
    if (raw == null || raw.isEmpty) return null;

    try {
      final catalog = Catalog.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      _memoryCatalog = catalog;
      return catalog;
    } catch (_) {
      await prefs.remove(catalogKey);
      return null;
    }
  }

  Future<Catalog> loadBundled() async {
    final raw = await rootBundle.loadString(assetPath);
    return Catalog.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  /// Sincroniza contra Orionis: `/ultima_actualizacion` → `/sincronizar_v2`.
  ///
  /// Idempotente y sin lanzar: cualquier fallo de red o de formato devuelve
  /// [SyncStatus.offline] con el catálogo local intacto (invariante 4).
  Future<SyncResult> syncRemote() async {
    final local = await loadLocal();
    final prefs = await SharedPreferences.getInstance();
    final stored = _decodeStoredV2(prefs.getString(catalogV2Key));

    try {
      final remoteTs = await _api.latestUpdate();
      if (local != null &&
          remoteTs != null &&
          remoteTs == stored?.apiTimestamp) {
        return SyncResult(
          catalog: local,
          status: SyncStatus.sinCambios,
          savedAt: stored?.savedAt,
        );
      }

      final payload = await _api.fetchCatalogPayload();
      final catalog = catalogFromSincronizarV2(payload);
      final savedAt = await _saveV2(payload);
      _memoryCatalog = catalog;
      return SyncResult(
        catalog: catalog,
        status: SyncStatus.actualizado,
        savedAt: savedAt,
      );
    } on CampusApiException catch (error) {
      return SyncResult(
        catalog: local,
        status: SyncStatus.offline,
        error: error,
        savedAt: stored?.savedAt,
      );
    } on FormatException {
      return SyncResult(
        catalog: local,
        status: SyncStatus.offline,
        savedAt: stored?.savedAt,
      );
    } catch (_) {
      // Contrato: syncRemote nunca lanza; se conserva lo local.
      return SyncResult(
        catalog: local,
        status: SyncStatus.offline,
        savedAt: stored?.savedAt,
      );
    }
  }

  Future<DateTime?> syncedAt() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = _decodeStoredV2(prefs.getString(catalogV2Key));
    if (stored?.savedAt != null) return stored!.savedAt;

    final raw = prefs.getString(syncedAtKey);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  /// Persiste la envoltura cruda en una sola escritura (reemplazo atómico).
  Future<DateTime> _saveV2(Map<String, dynamic> payload) async {
    final savedAt = DateTime.now();
    final apiTimestamp = payload['ultima_actualizacion'];
    final stored = <String, dynamic>{
      'saved_at': savedAt.toIso8601String(),
      'api_timestamp': apiTimestamp is String ? apiTimestamp : null,
      'payload': payload,
    };

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(catalogV2Key, jsonEncode(stored));
    return savedAt;
  }

  _StoredCatalog? _decodeStoredV2(String? raw) {
    if (raw == null || raw.isEmpty) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;

      final payload = decoded['payload'];
      if (payload is! Map<String, dynamic>) return null;

      final savedAt = decoded['saved_at'];
      final apiTimestamp = decoded['api_timestamp'];
      return _StoredCatalog(
        payload: payload,
        apiTimestamp: apiTimestamp is String ? apiTimestamp : null,
        savedAt: savedAt is String ? DateTime.tryParse(savedAt) : null,
      );
    } catch (_) {
      return null;
    }
  }

  /// Demo del prototipo: copia el catálogo de assets a la clave legacy.
  Future<Catalog> sync() async {
    await Future<void>.delayed(const Duration(milliseconds: 850));
    final raw = await rootBundle.loadString(assetPath);
    final catalog = Catalog.fromJson(jsonDecode(raw) as Map<String, dynamic>);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(catalogKey, raw);
    await prefs.setString(syncedAtKey, DateTime.now().toIso8601String());
    _memoryCatalog = catalog;
    return catalog;
  }

  Future<void> clearLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(catalogKey);
    await prefs.remove(syncedAtKey);
    await prefs.remove(catalogV2Key);
    _memoryCatalog = null;
  }
}

class _StoredCatalog {
  const _StoredCatalog({
    required this.payload,
    required this.apiTimestamp,
    required this.savedAt,
  });

  final Map<String, dynamic> payload;

  /// `ultima_actualizacion` de la envoltura guardada, si la traía.
  final String? apiTimestamp;

  final DateTime? savedAt;
}
