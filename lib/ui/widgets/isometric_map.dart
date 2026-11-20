import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/geo.dart';
import '../../data/models.dart';
import '../theme.dart';

/// Reproducción del mapa isométrico del wireframe con CustomPainter.
/// Cámara centrada en el usuario, norte arriba-derecha y aguja flotante a z=14.
class IsoSiteMap extends StatelessWidget {
  const IsoSiteMap({
    super.key,
    required this.user,
    required this.headingDeg,
    required this.bearingDeg,
    required this.targetPoint,
    required this.buildings,
    required this.highlightedCode,
  });

  final GeoPoint user;
  final double headingDeg;
  final double? bearingDeg;
  final GeoPoint? targetPoint;
  final List<Building> buildings;
  final String? highlightedCode;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.canvas,
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _IsoPainter(
            user: user,
            headingDeg: headingDeg,
            bearingDeg: bearingDeg,
            targetPoint: targetPoint,
            buildings: buildings,
            highlightedCode: highlightedCode,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _IsoPainter extends CustomPainter {
  _IsoPainter({
    required this.user,
    required this.headingDeg,
    required this.bearingDeg,
    required this.targetPoint,
    required this.buildings,
    required this.highlightedCode,
  });

  final GeoPoint user;
  final double headingDeg;
  final double? bearingDeg;
  final GeoPoint? targetPoint;
  final List<Building> buildings;
  final String? highlightedCode;

  static const double scale = 1.6;
  static const double _c30 = 0.8660254;
  static const double _s30 = 0.5;
  static const double _gridStep = 20;
  static const double _gridExtent = 260;
  static const double _needleLength = 38;
  static const double _needleZ = 14;
  static const double _coneRadius = 28;

  static const List<double> _walkwaysEast = [-60, 40, 140];
  static const List<double> _walkwaysNorth = [-45, 30, 120];

  /// Relleno del wireframe: [este, norte].
  static const List<List<double>> _filler = [
    [30, -40],
    [-40, 60],
    [90, 20],
    [180, 70],
    [-110, -60],
    [70, 150],
    [-60, -110],
    [190, -40],
    [-20, -170],
    [140, -150],
    [-150, 40],
    [20, 110],
  ];

  Offset _project(Size size, double east, double north, [double z = 0]) {
    final local = projectToCampus(user);
    final cx = size.width * 0.47;
    final cy = size.height * 0.33;
    return Offset(
      cx + ((east - local.east) + (north - local.north)) * _c30 * scale,
      cy +
          ((east - local.east) - (north - local.north)) * _s30 * scale -
          z * scale,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    final local = projectToCampus(user);

    _paintGrid(canvas, size, local);
    _paintWalkways(canvas, size, local);
    _paintRoute(canvas, size);
    _paintCone(canvas, size);
    _paintNeedle(canvas, size, local);

    final sites = <_Site>[];
    for (final entry in _filler) {
      sites.add(
        _Site(
          east: entry[0],
          north: entry[1],
          width: 18,
          depth: 18,
          height: 8 + ((entry[0] * 7 + entry[1] * 3) % 7 + 7) % 7,
          selected: false,
          code: null,
        ),
      );
    }
    for (final building in buildings) {
      final f = building.footprint;
      sites.add(
        _Site(
          east: f.east,
          north: f.north,
          width: f.width,
          depth: f.depth,
          height: f.height,
          selected: building.code == highlightedCode,
          code: building.code,
        ),
      );
    }
    sites.sort((a, b) => (a.east - a.north).compareTo(b.east - b.north));

    for (final site in sites) {
      _paintCube(canvas, size, site);
    }
    for (final site in sites) {
      if (site.code == null) continue;
      _paintLabel(canvas, size, site);
    }
  }

  void _paintGrid(Canvas canvas, Size size, LocalMeters local) {
    final paint = Paint()
      ..color = AppColors.grid
      ..strokeWidth = 1;
    final east0 = ((local.east - _gridExtent) / _gridStep).floor() * _gridStep;
    final north0 =
        ((local.north - _gridExtent) / _gridStep).floor() * _gridStep;

    for (var i = 0; i <= 26; i++) {
      final east = east0 + i * _gridStep;
      canvas.drawLine(
        _project(size, east, local.north - _gridExtent),
        _project(size, east, local.north + _gridExtent),
        paint,
      );
      final north = north0 + i * _gridStep;
      canvas.drawLine(
        _project(size, local.east - _gridExtent, north),
        _project(size, local.east + _gridExtent, north),
        paint,
      );
    }
  }

  void _paintWalkways(Canvas canvas, Size size, LocalMeters local) {
    final paint = Paint()
      ..color = AppColors.path
      ..strokeWidth = 1;
    for (final east in _walkwaysEast) {
      for (final offset in [-4.0, 4.0]) {
        canvas.drawLine(
          _project(size, east + offset, local.north - _gridExtent),
          _project(size, east + offset, local.north + _gridExtent),
          paint,
        );
      }
    }
    for (final north in _walkwaysNorth) {
      for (final offset in [-4.0, 4.0]) {
        canvas.drawLine(
          _project(size, local.east - _gridExtent, north + offset),
          _project(size, local.east + _gridExtent, north + offset),
          paint,
        );
      }
    }
  }

  void _paintRoute(Canvas canvas, Size size) {
    final point = targetPoint;
    if (point == null) return;
    final local = projectToCampus(user);
    final target = projectToCampus(point);
    final paint = Paint()
      ..color = AppColors.accent.withValues(alpha: 0.45)
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;
    _dashedLine(
      canvas,
      _project(size, local.east, local.north),
      _project(size, target.east, target.north),
      paint,
      dash: 2,
      gap: 5,
    );
  }

  void _paintCone(Canvas canvas, Size size) {
    final local = projectToCampus(user);
    final origin = _project(size, local.east, local.north);
    final path = Path()..moveTo(origin.dx, origin.dy);
    for (var angle = -30; angle <= 30; angle += 10) {
      final radians = toRadians(headingDeg + angle);
      final point = _project(
        size,
        local.east + _coneRadius * math.sin(radians),
        local.north + _coneRadius * math.cos(radians),
      );
      path.lineTo(point.dx, point.dy);
    }
    path.close();
    canvas.drawPath(
      path,
      Paint()..color = AppColors.accent.withValues(alpha: 0.09),
    );
  }

  void _paintNeedle(Canvas canvas, Size size, LocalMeters local) {
    final bearing = bearingDeg;
    if (bearing == null) return;

    final radians = toRadians(bearing);
    final tipEast = local.east + _needleLength * math.sin(radians);
    final tipNorth = local.north + _needleLength * math.cos(radians);

    final origin = _project(size, local.east, local.north);
    final groundTip = _project(size, tipEast, tipNorth);
    final base = _project(size, local.east, local.north, _needleZ);
    final tip = _project(size, tipEast, tipNorth, _needleZ);

    canvas.drawLine(
      origin,
      groundTip,
      Paint()
        ..color = AppColors.ink.withValues(alpha: 0.20)
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );

    final dashed = Paint()
      ..color = AppColors.accent
      ..strokeWidth = 1;
    _dashedLine(canvas, origin, base, dashed, dash: 2, gap: 3);
    _dashedLine(canvas, groundTip, tip, dashed, dash: 2, gap: 3);

    canvas.drawLine(
      base,
      tip,
      Paint()
        ..color = AppColors.accent
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );

    final vector = tip - base;
    final length = vector.distance;
    if (length > 0.1) {
      final ux = vector.dx / length;
      final uy = vector.dy / length;
      final head = Path()
        ..moveTo(tip.dx, tip.dy)
        ..lineTo(tip.dx - ux * 10 - uy * 4.5, tip.dy - uy * 10 + ux * 4.5)
        ..lineTo(tip.dx - ux * 10 + uy * 4.5, tip.dy - uy * 10 - ux * 4.5)
        ..close();
      canvas.drawPath(head, Paint()..color = AppColors.accent);
    }

    canvas.drawCircle(base, 3.5, Paint()..color = AppColors.page);
    canvas.drawCircle(
      base,
      3.5,
      Paint()
        ..color = AppColors.accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    final ring = Path();
    for (var angle = 0; angle < 360; angle += 20) {
      final radians = toRadians(angle.toDouble());
      final point = _project(
        size,
        local.east + 5 * math.sin(radians),
        local.north + 5 * math.cos(radians),
      );
      if (angle == 0) {
        ring.moveTo(point.dx, point.dy);
      } else {
        ring.lineTo(point.dx, point.dy);
      }
    }
    ring.close();
    canvas.drawPath(
      ring,
      Paint()..color = AppColors.accent.withValues(alpha: 0.14),
    );
    canvas.drawPath(
      ring,
      Paint()
        ..color = AppColors.accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    canvas.drawCircle(origin, 4.5, Paint()..color = AppColors.page);
    canvas.drawCircle(
      origin,
      4.5,
      Paint()
        ..color = AppColors.accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
  }

  void _paintCube(Canvas canvas, Size size, _Site site) {
    final x0 = site.east - site.width / 2;
    final x1 = site.east + site.width / 2;
    final y0 = site.north - site.depth / 2;
    final y1 = site.north + site.depth / 2;
    final h = site.height;

    final stroke = Paint()
      ..color = site.selected ? AppColors.accent : const Color(0xFFCFCCC5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = site.selected ? 1.5 : 1
      ..strokeJoin = StrokeJoin.round;

    final side = _polygon([
      _project(size, x1, y0),
      _project(size, x1, y1),
      _project(size, x1, y1, h),
      _project(size, x1, y0, h),
    ]);
    canvas.drawPath(side, Paint()..color = const Color(0xFFDAD7D1));
    canvas.drawPath(side, stroke);

    final front = _polygon([
      _project(size, x0, y0),
      _project(size, x1, y0),
      _project(size, x1, y0, h),
      _project(size, x0, y0, h),
    ]);
    canvas.drawPath(front, Paint()..color = const Color(0xFFE4E2DD));
    canvas.drawPath(front, stroke);

    final roof = _polygon([
      _project(size, x0, y0, h),
      _project(size, x1, y0, h),
      _project(size, x1, y1, h),
      _project(size, x0, y1, h),
    ]);
    canvas.drawPath(
      roof,
      Paint()..color = site.selected ? AppColors.page : const Color(0xFFF1EFEB),
    );
    canvas.drawPath(roof, stroke);
  }

  void _paintLabel(Canvas canvas, Size size, _Site site) {
    final point = _project(size, site.east, site.north, site.height + 7);
    final painter = TextPainter(
      text: TextSpan(
        text: site.code,
        style: TextStyle(
          fontFamily: 'SpaceMono',
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: site.selected ? AppColors.accent : AppColors.labelDim,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();
    painter.paint(
      canvas,
      Offset(point.dx - painter.width / 2, point.dy - painter.height),
    );
  }

  Path _polygon(List<Offset> points) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    return path..close();
  }

  void _dashedLine(
    Canvas canvas,
    Offset a,
    Offset b,
    Paint paint, {
    required double dash,
    required double gap,
  }) {
    final total = (b - a).distance;
    if (total <= 0) return;
    final direction = (b - a) / total;
    var travelled = 0.0;
    while (travelled < total) {
      final end = math.min(travelled + dash, total);
      canvas.drawLine(a + direction * travelled, a + direction * end, paint);
      travelled = end + gap;
    }
  }

  @override
  bool shouldRepaint(_IsoPainter oldDelegate) {
    final oldPoint = oldDelegate.targetPoint;
    final newPoint = targetPoint;
    return oldDelegate.user.lat != user.lat ||
        oldDelegate.user.lng != user.lng ||
        oldDelegate.headingDeg != headingDeg ||
        oldDelegate.bearingDeg != bearingDeg ||
        oldDelegate.highlightedCode != highlightedCode ||
        oldPoint?.lat != newPoint?.lat ||
        oldPoint?.lng != newPoint?.lng ||
        oldDelegate.buildings != buildings;
  }
}

class _Site {
  const _Site({
    required this.east,
    required this.north,
    required this.width,
    required this.depth,
    required this.height,
    required this.selected,
    required this.code,
  });

  final double east;
  final double north;
  final double width;
  final double depth;
  final double height;
  final bool selected;
  final String? code;
}
