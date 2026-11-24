import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import 'models.dart';

/// Obtiene (o reutiliza de caché) el archivo local de una URL remota.
typedef MediaFetcher = Future<File> Function(String url);

/// Servicio de medios remotos con caché en disco.
///
/// No guarda estado propio más allá de las funciones inyectadas: la caché es
/// la del [BaseCacheManager] y las fotos las resuelve `CachedNetworkImage`.
class MediaCache {
  MediaCache({
    MediaFetcher? fetcher,
    ImageProvider Function(String url)? imageFactory,
  }) : _fetcher = fetcher ?? _defaultFetcher,
       _imageFactory = imageFactory ?? _defaultImageFactory;

  final MediaFetcher _fetcher;
  final ImageProvider Function(String url) _imageFactory;

  static Future<File> _defaultFetcher(String url) =>
      DefaultCacheManager().getSingleFile(url);

  static ImageProvider _defaultImageFactory(String url) =>
      CachedNetworkImageProvider(url);

  /// Archivo de video en caché, o `null` si la URL es vacía/nula o falla la
  /// descarga. Nunca lanza.
  ///
  /// La descarga se corta a los [timeout]; al vencer devuelve `null` como
  /// cualquier otro fallo para no bloquear la ficha.
  Future<File?> videoFile(
    String? url, {
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final remote = _remoteUrl(url);
    if (remote == null) return null;

    try {
      return await _fetcher(remote).timeout(timeout);
    } catch (_) {
      // Sin red, 404, formato inválido o timeout: la ficha degrada a
      // "abrir enlace".
      return null;
    }
  }

  /// Proveedor de imagen cacheada para `CachedNetworkImageProvider`.
  ImageProvider imageProvider(String url) => _imageFactory(url);

  /// Descarga hasta [max] videos distintos del catálogo, en paralelo, sin
  /// lanzar.
  ///
  /// Cada descarga respeta [timeout], así que el peor caso es un ciclo de
  /// [timeout] (no `max × timeout`). Devuelve cuántos archivos se obtuvieron
  /// con éxito; los fallos se ignoran.
  Future<int> prefetchVideos(
    Catalog catalog, {
    int max = 3,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    if (max <= 0) return 0;

    final seen = <String>{};
    final targets = <String>[];
    for (final building in catalog.buildings) {
      final url = _remoteUrl(building.videoUrl);
      if (url == null || !seen.add(url)) continue;
      targets.add(url);
      if (targets.length >= max) break;
    }
    if (targets.isEmpty) return 0;

    final files = await Future.wait(
      targets.map((url) => videoFile(url, timeout: timeout)),
    );
    return files.where((file) => file != null).length;
  }

  /// URL remota normalizada, o `null` si es nula, vacía o no es http/https.
  static String? _remoteUrl(String? url) {
    if (url == null) return null;
    final trimmed = url.trim();
    if (trimmed.isEmpty) return null;

    final uri = Uri.tryParse(trimmed);
    if (uri == null) return null;
    if (uri.scheme != 'http' && uri.scheme != 'https') return null;
    return trimmed;
  }
}
