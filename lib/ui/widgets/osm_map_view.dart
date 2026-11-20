import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../state/navigation_controller.dart';
import '../theme.dart';

/// Extra +3: vista alternativa con capas libres de OpenStreetMap y polyline.
/// La aguja sigue siendo la vista principal; esto es complementario.
class OsmMapView extends StatefulWidget {
  const OsmMapView({super.key, required this.controller});

  final NavigationController controller;

  @override
  State<OsmMapView> createState() => _OsmMapViewState();
}

class _OsmMapViewState extends State<OsmMapView> {
  final MapController _mapController = MapController();
  bool _ready = false;
  double? _lastLat;
  double? _lastLng;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_followUser);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_followUser);
    _mapController.dispose();
    super.dispose();
  }

  void _followUser() {
    if (!_ready || !mounted) return;
    final lat = widget.controller.latitude;
    final lng = widget.controller.longitude;
    if (_lastLat != null &&
        _lastLng != null &&
        (lat - _lastLat!).abs() < 0.000001 &&
        (lng - _lastLng!).abs() < 0.000001) {
      return;
    }
    _lastLat = lat;
    _lastLng = lng;
    _mapController.move(LatLng(lat, lng), _mapController.camera.zoom);
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final user = LatLng(controller.latitude, controller.longitude);
    final target = controller.targetPoint;

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: user,
        initialZoom: 17.4,
        minZoom: 14,
        maxZoom: 19,
        backgroundColor: AppColors.canvas,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
        onMapReady: () {
          _ready = true;
          _lastLat = controller.latitude;
          _lastLng = controller.longitude;
        },
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'uthmap.prototype',
          maxNativeZoom: 19,
        ),
        if (target != null)
          PolylineLayer(
            polylines: [
              Polyline(
                points: [user, LatLng(target.lat, target.lng)],
                color: AppColors.accent,
                strokeWidth: 3,
                borderColor: Colors.white,
                borderStrokeWidth: 5,
              ),
            ],
          ),
        MarkerLayer(
          markers: [
            for (final building in controller.buildings)
              Marker(
                point: LatLng(
                  building.mainEntrance.lat,
                  building.mainEntrance.lng,
                ),
                width: 44,
                height: 36,
                alignment: Alignment.center,
                child: GestureDetector(
                  onTap: () => controller.selectTarget(building),
                  child: _BuildingMarker(
                    code: building.code,
                    active: building.id == controller.target?.id,
                  ),
                ),
              ),
            Marker(
              point: user,
              width: 44,
              height: 44,
              child: _UserMarker(headingDeg: controller.heading),
            ),
          ],
        ),
      ],
    );
  }
}

class _UserMarker extends StatelessWidget {
  const _UserMarker({required this.headingDeg});

  final double headingDeg;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.accent, width: 2),
          boxShadow: [
            BoxShadow(
              color: AppColors.ink.withValues(alpha: 0.18),
              blurRadius: 6,
            ),
          ],
        ),
        child: Transform.rotate(
          angle: headingDeg * math.pi / 180,
          child: const Icon(
            Icons.navigation,
            size: 20,
            color: AppColors.accent,
          ),
        ),
      ),
    );
  }
}

class _BuildingMarker extends StatelessWidget {
  const _BuildingMarker({required this.code, required this.active});

  final String code;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: active ? AppColors.ink : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: active ? AppColors.ink : AppColors.line),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.14),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        code,
        textAlign: TextAlign.center,
        style: AppTheme.mono(
          size: 11,
          weight: FontWeight.w700,
          color: active ? Colors.white : AppColors.ink,
        ),
      ),
    );
  }
}

void showOsmAttribution(BuildContext context) {
  // Mantiene una atribución textual visible sobre el panel inferior.
  unawaited(
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.page,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Datos del mapa',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Teselas y datos del mapa: © OpenStreetMap contributors, disponibles bajo la Open Database License (ODbL).',
          style: TextStyle(fontSize: 13, height: 1.5, color: AppColors.dim),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Cerrar',
              style: TextStyle(fontSize: 12, color: AppColors.accent),
            ),
          ),
        ],
      ),
    ),
  );
}
