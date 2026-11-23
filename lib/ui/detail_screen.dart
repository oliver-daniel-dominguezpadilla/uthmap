import 'package:flutter/material.dart';

import '../data/media_cache.dart';
import '../data/models.dart';
import '../state/navigation_controller.dart';
import 'credits.dart';
import 'theme.dart';
import 'widgets/building_photo.dart';
import 'widgets/primitives.dart';
import 'widgets/video_sheet.dart';

/// Caché de medios por defecto cuando la pantalla se construye sin inyectarla
/// (por ejemplo desde el directorio). `MediaCache` no guarda estado propio.
final MediaCache _defaultMediaCache = MediaCache();

/// Ficha completa del edificio: foto, dependencias, horarios, etiquetas,
/// coordenadas 1:N y el acceso directo a la navegación.
class DetailScreen extends StatelessWidget {
  const DetailScreen({
    super.key,
    required this.building,
    required this.controller,
    this.mediaCache,
  });

  final Building building;
  final NavigationController controller;
  final MediaCache? mediaCache;

  void _goTo(BuildContext context) {
    controller.selectTarget(building);
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final mediaCache = this.mediaCache ?? _defaultMediaCache;
    final topInset = MediaQuery.paddingOf(context).top;
    final distance = controller.nearestEntranceTo(building)?.distanceM;
    final entrances = building.coordinates
        .where((coordinate) => coordinate.type.isEntrance)
        .toList(growable: false);

    return Scaffold(
      backgroundColor: AppColors.page,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _Hero(
              building: building,
              topInset: topInset,
              mediaCache: mediaCache,
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TinyLabel(
                    '${building.category.label} · ${building.areaLabel}',
                    color: AppColors.dim,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    building.name,
                    style: const TextStyle(
                      fontFamily: 'SpaceGrotesk',
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      height: 1.08,
                      letterSpacing: -0.9,
                      color: AppColors.ink,
                    ),
                  ),
                  if (distance != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(
                          Icons.near_me_outlined,
                          size: 14,
                          color: AppColors.accent,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'A ${distance.round()} m de tu ubicación · '
                            'cobertura ${building.coverageRadiusM.round()} m',
                            maxLines: 2,
                            style: AppTheme.mono(
                              size: 11,
                              color: AppColors.dim,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  Text(
                    building.description,
                    style: const TextStyle(
                      fontFamily: 'SpaceGrotesk',
                      fontSize: 14.5,
                      height: 1.62,
                      color: AppColors.dim,
                    ),
                  ),
                  const SectionRule(),
                  _MetaPair(
                    leftLabel: 'Horario',
                    leftValue: building.hours,
                    rightLabel: 'Categoría',
                    rightValue: building.category.label,
                  ),
                  const SectionRule(),
                  const TinyLabel('Dependencias'),
                  const SizedBox(height: 10),
                  for (var i = 0; i < building.dependencies.length; i++)
                    _DependencyRow(
                      index: (i + 1).toString().padLeft(2, '0'),
                      label: building.dependencies[i],
                    ),
                  const SectionRule(),
                  const TinyLabel('Etiquetas'),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final tag in building.tags)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.muted,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            tag,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.dim,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SectionRule(),
                  const TinyLabel('Coordenadas'),
                  const SizedBox(height: 10),
                  for (final coordinate in entrances)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              _coordinateLabel(coordinate.type),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: AppColors.ink,
                              ),
                            ),
                          ),
                          Text(
                            '${coordinate.lat.toStringAsFixed(5)}, '
                            '${coordinate.lng.toStringAsFixed(5)}',
                            style: AppTheme.mono(
                              size: 10.5,
                              color: AppColors.dim,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SectionRule(),
                  if (building.videoAsset != null ||
                      building.videoUrl != null) ...[
                    BlackButton(
                      label: kVideoCta,
                      height: 46,
                      onPressed: () =>
                          showVideoSheet(context, building, mediaCache),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Clip demostrativo incluido en la app; no requiere conexión.',
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.5,
                        color: AppColors.dim.withValues(alpha: 0.9),
                      ),
                    ),
                  ] else ...[
                    const OutlineButton(
                      label: 'RECORRIDO EN VIDEO NO DISPONIBLE',
                      height: 46,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Este inmueble aún no tiene clip. La ficha y la guía por brújula sí están completas.',
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.5,
                        color: AppColors.dim,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Center(
                    child: TextButton(
                      onPressed: () => showCredits(context),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.dim,
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 32),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Créditos de fotografías y mapa',
                        style: TextStyle(
                          fontSize: 11,
                          decoration: TextDecoration.underline,
                          decorationColor: AppColors.dim,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.page,
          border: Border(top: BorderSide(color: AppColors.lineSoft)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        child: SafeArea(
          top: false,
          child: BlackButton(
            label: 'CÓMO LLEGAR',
            icon: Icons.near_me_outlined,
            height: 48,
            onPressed: () => _goTo(context),
          ),
        ),
      ),
    );
  }
}

String _coordinateLabel(CoordinateType type) => switch (type) {
  CoordinateType.entradaPrincipal => 'Entrada principal',
  CoordinateType.entradaSecundaria => 'Entrada secundaria',
  CoordinateType.perimetro => 'Perímetro',
};

class _Hero extends StatelessWidget {
  const _Hero({
    required this.building,
    required this.topInset,
    required this.mediaCache,
  });

  final Building building;
  final double topInset;
  final MediaCache mediaCache;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 250,
      child: Stack(
        fit: StackFit.expand,
        children: [
          BuildingPhoto(
            building: building,
            mediaCache: mediaCache,
            fit: BoxFit.cover,
            memCacheWidth: 1280,
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x66111317),
                  Color(0x00111317),
                  Color(0x99111317),
                ],
                stops: [0, 0.45, 1],
              ),
            ),
          ),
          Positioned(
            top: topInset + 12,
            left: 16,
            right: 16,
            child: Row(
              children: [
                RoundIconButton(
                  icon: Icons.arrow_back,
                  tooltip: 'Volver',
                  background: AppColors.page,
                  borderColor: AppColors.page,
                  onTap: () => Navigator.of(context).maybePop(),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.page.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    building.code,
                    style: AppTheme.mono(
                      size: 12,
                      weight: FontWeight.w700,
                      color: AppColors.ink,
                      letterSpacing: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 22,
            bottom: 16,
            child: Text(
              '${building.areaLabel.toUpperCase()} · CAMPUS',
              style: AppTheme.mono(
                size: 10,
                weight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.82),
                letterSpacing: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaPair extends StatelessWidget {
  const _MetaPair({
    required this.leftLabel,
    required this.leftValue,
    required this.rightLabel,
    required this.rightValue,
  });

  final String leftLabel;
  final String leftValue;
  final String rightLabel;
  final String rightValue;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TinyLabel(leftLabel),
              const SizedBox(height: 6),
              Text(
                leftValue,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TinyLabel(rightLabel),
              const SizedBox(height: 6),
              Text(
                rightValue,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DependencyRow extends StatelessWidget {
  const _DependencyRow({required this.index, required this.label});

  final String index;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 26,
            child: Text(
              index,
              style: AppTheme.mono(
                size: 10,
                color: AppColors.accent,
                letterSpacing: 0.6,
              ),
            ),
          ),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                height: 1.4,
                color: AppColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
