import 'dart:async';

import 'package:flutter/material.dart';

import '../data/models.dart';
import '../state/nav_state.dart';
import '../state/navigation_controller.dart';
import 'credits.dart';
import 'detail_screen.dart';
import 'directory_screen.dart';
import 'theme.dart';
import 'widgets/isometric_map.dart';
import 'widgets/nav_sheet.dart';
import 'widgets/osm_map_view.dart';
import 'widgets/primitives.dart';
import 'widgets/sensor_panel.dart';
import 'widgets/video_sheet.dart';

enum _MenuAction { explore, osm, directory, sensors, credits, reset }

/// Pantalla principal: reproduce el stage de 375×760 del wireframe y, en
/// escritorio, añade el panel lateral de 220 px con los sensores.
class NavigationScreen extends StatefulWidget {
  const NavigationScreen({super.key, required this.controller});

  final NavigationController controller;

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  late final TextEditingController _search;
  final FocusNode _focus = FocusNode();
  bool _sheetExpanded = true;
  bool _showOsm = false;

  NavigationController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _search = TextEditingController();
    _search.addListener(_refresh);
    _focus.addListener(_refresh);
    _controller.onArrival = _onArrival;
  }

  @override
  void dispose() {
    _controller.onArrival = null;
    _search
      ..removeListener(_refresh)
      ..dispose();
    _focus
      ..removeListener(_refresh)
      ..dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  List<Building> get _results {
    final query = _search.text.trim();
    if (query.isEmpty) return const [];
    return _controller.buildings
        .where((building) => building.matches(query))
        .take(4)
        .toList(growable: false);
  }

  bool get _resultsVisible => _focus.hasFocus && _search.text.trim().isNotEmpty;

  void _onArrival(Building building) {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              DetailScreen(building: building, controller: _controller),
        ),
      );
    });
  }

  void _select(Building building) {
    _search.clear();
    _focus.unfocus();
    _controller.selectTarget(building);
    setState(() => _sheetExpanded = true);
  }

  void _submitSearch([String? _]) {
    final results = _results;
    if (results.isNotEmpty) _select(results.first);
  }

  void _openDetail(Building building) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            DetailScreen(building: building, controller: _controller),
      ),
    );
  }

  Future<void> _openDirectory() async {
    _focus.unfocus();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DirectoryScreen(controller: _controller),
      ),
    );
    if (mounted) setState(() {});
  }

  void _playVideo(Building building) {
    unawaited(showVideoSheet(context, building));
  }

  void _openSensors() {
    unawaited(showSensorPanel(context, _controller));
  }

  void _handleMenu(_MenuAction action) {
    switch (action) {
      case _MenuAction.explore:
        _controller.clearTarget();
        setState(() => _sheetExpanded = true);
        break;
      case _MenuAction.osm:
        setState(() => _showOsm = !_showOsm);
        break;
      case _MenuAction.directory:
        unawaited(_openDirectory());
        break;
      case _MenuAction.sensors:
        _openSensors();
        break;
      case _MenuAction.credits:
        unawaited(showCredits(context));
        break;
      case _MenuAction.reset:
        _controller.resetDemo();
        setState(() => _sheetExpanded = true);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.page,
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          return LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 900;
              if (wide) {
                return _wideLayout(context);
              }
              final padding = MediaQuery.paddingOf(context);
              return Padding(
                padding: EdgeInsets.only(top: padding.top),
                child: SizedBox.expand(
                  child: _stage(context, bottomInset: padding.bottom),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _wideLayout(BuildContext context) {
    return ColoredBox(
      color: AppColors.page,
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  width: 375,
                  height: 760,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: AppColors.canvas,
                    border: Border.all(color: AppColors.line),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: _stage(context, bottomInset: 0),
                ),
                const SizedBox(width: 64),
                SizedBox(
                  width: 220,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SensorPanel(
                        controller: _controller,
                        compact: true,
                        advanced: false,
                        onOpenAdvanced: _openSensors,
                      ),
                      const SizedBox(height: 6),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _stage(BuildContext context, {required double bottomInset}) {
    final controller = _controller;
    final sheetHeight =
        (_sheetExpanded ? NavSheet.expandedHeight : NavSheet.collapsedHeight) +
        bottomInset;
    final banner = _statusBanner(context);

    return Stack(
      children: [
        Positioned.fill(
          child: _showOsm
              ? OsmMapView(controller: controller)
              : IsoSiteMap(
                  user: controller.position,
                  headingDeg: controller.heading,
                  bearingDeg: controller.bearingDeg,
                  targetPoint: controller.targetPoint,
                  buildings: controller.buildings,
                  highlightedCode: controller.target?.code,
                ),
        ),
        Positioned(
          top: 16,
          left: 14,
          right: 14,
          child: UthSearchField(
            controller: _search,
            focusNode: _focus,
            onChanged: (_) => _refresh(),
            onSubmitted: _submitSearch,
            trailing: _avatarButton(context),
          ),
        ),
        if (_resultsVisible)
          Positioned(
            top: 72,
            left: 14,
            right: 14,
            child: _resultsPanel(context),
          ),
        if (banner != null || _showOsm)
          Positioned(
            left: 14,
            right: 14,
            bottom: sheetHeight + 12,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ?banner,
                if (_showOsm) ...[
                  if (banner != null) const SizedBox(height: 8),
                  _AttributionPill(onTap: () => showOsmAttribution(context)),
                ],
              ],
            ),
          ),
        Align(
          alignment: Alignment.bottomCenter,
          child: NavSheet(
            controller: controller,
            expanded: _sheetExpanded,
            bottomInset: bottomInset,
            onExpanded: (value) => setState(() => _sheetExpanded = value),
            onPlayVideo: _playVideo,
            onOpenDetail: _openDetail,
            onOpenDirectory: () => unawaited(_openDirectory()),
          ),
        ),
      ],
    );
  }

  Widget _avatarButton(BuildContext context) {
    return PopupMenuButton<_MenuAction>(
      tooltip: 'Perfil y opciones',
      offset: const Offset(0, 44),
      color: AppColors.page,
      elevation: 10,
      constraints: const BoxConstraints(minWidth: 226, maxWidth: 280),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.lineSoft),
      ),
      onSelected: _handleMenu,
      itemBuilder: (context) {
        final hasTarget = _controller.target != null;
        return [
          _menuItem(
            _MenuAction.explore,
            'Explorar sin destino',
            Icons.explore_outlined,
            enabled: hasTarget,
          ),
          _menuItem(
            _MenuAction.osm,
            _showOsm ? 'Volver al mapa isométrico' : 'Ver mapa OSM',
            _showOsm ? Icons.grid_view_outlined : Icons.map_outlined,
          ),
          _menuItem(
            _MenuAction.directory,
            'Directorio de edificios',
            Icons.menu_book_outlined,
          ),
          _menuItem(_MenuAction.sensors, 'Panel de sensores', Icons.tune),
          _menuItem(_MenuAction.credits, 'Créditos', Icons.info_outline),
          _menuItem(
            _MenuAction.reset,
            'Reiniciar demostración',
            Icons.restart_alt,
          ),
        ];
      },
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: AppColors.ink,
          shape: BoxShape.circle,
        ),
        child: const Text(
          'CR',
          style: TextStyle(
            fontFamily: 'SpaceGrotesk',
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  PopupMenuItem<_MenuAction> _menuItem(
    _MenuAction action,
    String label,
    IconData icon, {
    bool enabled = true,
  }) {
    return PopupMenuItem<_MenuAction>(
      value: action,
      enabled: enabled,
      height: 44,
      child: Row(
        children: [
          Icon(icon, size: 17, color: enabled ? AppColors.dim : AppColors.line),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'SpaceGrotesk',
                fontSize: 13,
                color: enabled ? AppColors.ink : AppColors.line,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultsPanel(BuildContext context) {
    final results = _results;
    return Material(
      color: AppColors.page,
      elevation: 8,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: results.isEmpty
          ? const Padding(
              padding: EdgeInsets.fromLTRB(16, 13, 16, 13),
              child: Text(
                'Sin resultados',
                style: TextStyle(fontSize: 13, color: AppColors.dim),
              ),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final building in results)
                  InkWell(
                    onTap: () => _select(building),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(16, 11, 16, 11),
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: AppColors.lineSoft),
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(
                            building.code,
                            style: AppTheme.mono(
                              size: 10,
                              weight: FontWeight.w700,
                              color: AppColors.accent,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '${building.name} — ${building.areaLabel}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: AppColors.ink,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget? _statusBanner(BuildContext context) {
    final gps = _controller.gpsStatus;
    final compass = _controller.compassStatus;
    if (gps == SensorStatus.ok && compass == SensorStatus.ok) return null;
    final message =
        _controller.gpsMessage ??
        _controller.compassMessage ??
        'Sensores en pausa.';
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 9, 6, 9),
      decoration: BoxDecoration(
        color: AppColors.page,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.lineSoft),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(
            Icons.sensors_off_outlined,
            size: 16,
            color: AppColors.accent,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                height: 1.4,
                color: AppColors.dim,
              ),
            ),
          ),
          TextButton(
            onPressed: _openSensors,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.accent,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 30),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'AJUSTES',
              style: TextStyle(
                fontFamily: 'SpaceMono',
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AttributionPill extends StatelessWidget {
  const _AttributionPill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.page.withValues(alpha: 0.92),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Text(
            '© OpenStreetMap',
            style: AppTheme.mono(
              size: 9.5,
              color: AppColors.dim,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
    );
  }
}
