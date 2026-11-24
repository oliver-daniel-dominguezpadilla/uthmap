import 'package:flutter/material.dart';

import '../../data/media_cache.dart';
import '../../data/models.dart';
import '../../state/navigation_controller.dart';
import '../theme.dart';
import 'building_photo.dart';
import 'primitives.dart';

class NavSheet extends StatefulWidget {
  const NavSheet({
    super.key,
    required this.controller,
    required this.expanded,
    required this.bottomInset,
    required this.onExpanded,
    required this.onPlayVideo,
    required this.onOpenDetail,
    required this.onOpenDirectory,
    this.mediaCache,
  });

  final NavigationController controller;
  final bool expanded;
  final double bottomInset;
  final ValueChanged<bool> onExpanded;
  final ValueChanged<Building> onPlayVideo;
  final ValueChanged<Building> onOpenDetail;
  final VoidCallback onOpenDirectory;
  final MediaCache? mediaCache;

  static const double collapsedHeight = 146;
  static const double expandedHeight = 218;

  @override
  State<NavSheet> createState() => _NavSheetState();
}

class _NavSheetState extends State<NavSheet> {
  late final MediaCache _mediaCache = widget.mediaCache ?? MediaCache();
  double _dragDy = 0;

  void _handleTap() => widget.onExpanded(!widget.expanded);

  void _handleDragStart(DragStartDetails details) => _dragDy = 0;

  void _handleDragUpdate(DragUpdateDetails details) {
    _dragDy += details.delta.dy;
  }

  void _handleDragEnd(DragEndDetails details) {
    if (_dragDy > 30) {
      widget.onExpanded(false);
    } else if (_dragDy < -30) {
      widget.onExpanded(true);
    } else {
      widget.onExpanded(!widget.expanded);
    }
    _dragDy = 0;
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final target = controller.target;
    final nearby = controller.nearby;
    final directed = target != null;
    final active = directed ? target : nearby;
    final inside = directed ? controller.insideTargetArea : nearby != null;
    final distance = controller.distanceM;

    final title = directed
        ? target.name
        : (nearby?.name ?? 'Explorando el campus');
    final areaText = inside && active != null
        ? '• ${active.areaLabel}'
        : (directed ? '○ Fuera del área' : '○ Sin destino');
    final hint = directed
        ? (controller.quadrantHintText ??
              'Selecciona un destino para orientar la aguja.')
        : (nearby != null
              ? 'Estás dentro del área. Abre la ficha para consultar los detalles.'
              : 'Camina por el campus; te avisamos al pasar junto a un edificio.');
    final distanceText = controller.arrived
        ? 'Llegaste'
        : (distance == null ? '—' : '${distance.round()} m');

    final height =
        (widget.expanded ? NavSheet.expandedHeight : NavSheet.collapsedHeight) +
        widget.bottomInset;

    return AnimatedContainer(
      duration: kSheet,
      curve: kEase,
      height: height,
      clipBehavior: Clip.hardEdge,
      decoration: const BoxDecoration(
        color: AppColors.page,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Color(0x1F111317),
            blurRadius: 10,
            offset: Offset(0, -1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            expanded: widget.expanded,
            label: 'Expandir o contraer panel',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _handleTap,
              onVerticalDragStart: _handleDragStart,
              onVerticalDragUpdate: _handleDragUpdate,
              onVerticalDragEnd: _handleDragEnd,
              child: SizedBox(
                height: 28,
                child: Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(top: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD6D4CF),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            // Con poco alto (360×800) el contenido puede no caber, sobre todo
            // mientras el contenedor crece al expandirse: el scroll —sin
            // desplazamiento real— evita el desbordamiento sin cambiar
            // tamaños, colores ni el orden del wireframe.
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        22,
                        2,
                        22,
                        22 + widget.bottomInset,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (nearby != null && !directed) ...[
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: SizedBox(
                                        width: 44,
                                        height: 44,
                                        child: BuildingPhoto(
                                          building: nearby,
                                          mediaCache: _mediaCache,
                                          fit: BoxFit.cover,
                                          memCacheWidth: 132,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                  ],
                                  Expanded(
                                    child: Padding(
                                      padding: EdgeInsets.only(
                                        top: (nearby != null && !directed)
                                            ? 8
                                            : 0,
                                      ),
                                      child: Text(
                                        title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontFamily: 'SpaceGrotesk',
                                          fontSize: 20,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: -0.2,
                                          color: AppColors.ink,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  CategoryPill(text: areaText, active: inside),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text(
                                    distanceText,
                                    style: const TextStyle(
                                      fontFamily: 'SpaceGrotesk',
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.ink,
                                      fontFeatures: [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Text(
                                      hint,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontFamily: 'SpaceGrotesk',
                                        fontSize: 12,
                                        height: 1.4,
                                        color: Color(0xFF737373),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          if (widget.expanded)
                            _cta(context, directed, target, nearby),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _cta(
    BuildContext context,
    bool directed,
    Building? target,
    Building? nearby,
  ) {
    if (directed) {
      if (target!.videoAsset != null || target.videoUrl != null) {
        return BlackButton(
          label: kVideoCta,
          onPressed: () => widget.onPlayVideo(target),
        );
      }
      return BlackButton(
        label: 'VER FICHA COMPLETA',
        onPressed: () => widget.onOpenDetail(target),
      );
    }
    if (nearby != null) {
      return BlackButton(
        label: 'VER FICHA DEL EDIFICIO',
        onPressed: () => widget.onOpenDetail(nearby),
      );
    }
    return BlackButton(
      label: 'ELEGIR DESTINO',
      onPressed: widget.onOpenDirectory,
    );
  }
}
