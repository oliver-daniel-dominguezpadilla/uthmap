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
  Future<File?> videoFile(String? url) async {
    final remote = _remoteUrl(url);
    if (remote == null) return null;

    try {
      return await _fetcher(remote);
    } catch (_) {
      // Sin red, 404, formato inválido: la ficha degrada a "abrir enlace".
      return null;
    }
  }

  /// Proveedor de imagen cacheada para `CachedNetworkImageProvider`.
  ImageProvider imageProvider(String url) => _imageFactory(url);

  /// Descarga hasta [max] videos distintos del catálogo, en orden, sin lanzar.
  ///
  /// Devuelve cuántos archivos se obtuvieron con éxito; los fallos se ignoran.
  Future<int> prefetchVideos(Catalog catalog, {int max = 3}) async {
    if (max <= 0) return 0;

    final seen = <String>{};
    final targets = <String>[];
    for (final building in catalog.buildings) {
      final url = _remoteUrl(building.videoUrl);
      if (url == null || !seen.add(url)) continue;
      targets.add(url);
      if (targets.length >= max) break;
    }

    var downloaded = 0;
    for (final url in targets) {
      final file = await videoFile(url);
      if (file != null) downloaded++;
    }
    return downloaded;
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
