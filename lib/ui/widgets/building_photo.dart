import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../data/media_cache.dart';
import '../../data/models.dart';
import '../theme.dart';

/// Foto de un edificio con la política única de la app:
///
/// 1. Si el catálogo trae `photoUrl`, se sirve en remoto con
///    [CachedNetworkImage] (caché en disco propia del paquete).
/// 2. Si falla la red —o no hay `photoUrl`— se usa el asset incluido.
/// 3. Si tampoco hay asset, queda el color de relleno del wireframe.
///
/// No añade sombras, bordes ni overlays: el encuadre y los recortes los pone
/// quien lo inserta.
class BuildingPhoto extends StatelessWidget {
  const BuildingPhoto({
    super.key,
    required this.building,
    required this.mediaCache,
    this.fit = BoxFit.cover,
    this.placeholderColor = AppColors.muted,
    this.memCacheWidth,
  });

  final Building building;

  /// Dependencia compartida de la capa visual. La foto remota la cachea
  /// `CachedNetworkImage`; este campo mantiene un único punto de inyección
  /// para los medios del edificio.
  final MediaCache mediaCache;

  final BoxFit fit;

  /// Relleno mientras no hay píxeles (mismo token que el prototipo).
  final Color placeholderColor;

  /// Ancho al que se decodifica la imagen en memoria.
  final int? memCacheWidth;

  @override
  Widget build(BuildContext context) {
    final url = building.photoUrl;
    if (url == null) return _fallback();

    return CachedNetworkImage(
      imageUrl: url,
      fit: fit,
      memCacheWidth: memCacheWidth,
      placeholder: (_, _) => ColoredBox(color: placeholderColor),
      errorWidget: (_, _, _) => _fallback(),
    );
  }

  Widget _fallback() {
    final asset = building.photoAsset;
    if (asset == null) return ColoredBox(color: placeholderColor);
    return Image.asset(asset, fit: fit, cacheWidth: memCacheWidth);
  }
}
