import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/catalog_repository.dart';
import '../data/models.dart';
import 'credits.dart';
import 'theme.dart';
import 'widgets/primitives.dart';

/// Primera ejecución: sincronización real del catálogo 1:N contra Orionis.
/// Después de este paso la app funciona sin conexión.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({
    super.key,
    required this.repository,
    required this.onReady,
  });

  final CatalogRepository repository;

  /// Entrega el catálogo efectivo; `offline` indica que se conservó el local.
  final void Function(Catalog catalog, {bool offline}) onReady;

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool _syncing = false;
  bool _finishing = false;
  String? _error;
  DateTime? _lastSync;

  @override
  void initState() {
    super.initState();
    _loadLastSync();
  }

  Future<void> _loadLastSync() async {
    final value = await widget.repository.syncedAt();
    if (!mounted || value == null) return;
    setState(() => _lastSync = value);
  }

  Future<void> _sync() async {
    if (_syncing) return;
    setState(() {
      _syncing = true;
      _error = null;
    });
    try {
      final result = await widget.repository.syncRemote();
      final catalog = result.catalog ?? await widget.repository.loadBundled();
      if (!mounted) return;
      _finishing = true;
      widget.onReady(catalog, offline: result.status == SyncStatus.offline);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _syncing = false;
        _error = 'No se pudo sincronizar el catálogo. Inténtalo de nuevo.';
      });
    }
  }

  Future<void> _skip() async {
    if (_syncing || _finishing) return;
    setState(() {
      _syncing = true;
      _error = null;
    });
    try {
      final catalog = await widget.repository.loadBundled();
      if (!mounted) return;
      _finishing = true;
      widget.onReady(catalog);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _syncing = false;
        _error = 'No se pudo abrir el catálogo incluido.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.page,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 26),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: math.max(0, constraints.maxHeight - 48),
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 430),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _BrandRow(lastSync: _lastSync),
                            SizedBox(
                              height: constraints.maxHeight > 820 ? 64 : 30,
                            ),
                            const _CompassMark(size: 76),
                            const SizedBox(height: 24),
                            const Text(
                              'El campus,\nsin perder\nel rumbo.',
                              style: TextStyle(
                                fontFamily: 'SpaceGrotesk',
                                fontSize: 40,
                                fontWeight: FontWeight.w700,
                                height: 1.02,
                                letterSpacing: -1.6,
                                color: AppColors.ink,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'UthMap te orienta con la brújula del teléfono: '
                              'te dice hacia dónde girar y te avisa cuando '
                              'estás frente al edificio correcto.',
                              style: TextStyle(
                                fontFamily: 'SpaceGrotesk',
                                fontSize: 14.5,
                                height: 1.62,
                                color: AppColors.dim,
                              ),
                            ),
                            const SizedBox(height: 26),
                            const _Step(
                              index: '01',
                              title: 'Sincroniza una vez',
                              body: 'Descarga el catálogo de edificios y sus puntos de acceso.',
                            ),
                            const _Step(
                              index: '02',
                              title: 'Camina con la brújula',
                              body: 'La aguja apunta al acceso; el panel te dice el rumbo y la distancia.',
                            ),
                            const _Step(
                              index: '03',
                              title: 'Llega y consulta',
                              body: 'Aviso a 20 m, llegada a 15 m y ficha completa del inmueble.',
                              last: true,
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 28),
                            if (_syncing) ...[
                              const ClipRRect(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(2),
                                ),
                                child: LinearProgressIndicator(
                                  minHeight: 2,
                                  color: AppColors.accent,
                                  backgroundColor: AppColors.lineSoft,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Descargando catálogo 1:N · 5 edificios · 30 puntos',
                                style: AppTheme.mono(
                                  size: 10.5,
                                  color: AppColors.dim,
                                  letterSpacing: 0.2,
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                            BlackButton(
                              label: _syncing
                                  ? 'SINCRONIZANDO…'
                                  : 'SINCRONIZAR CAMPUS',
                              icon: Icons.cloud_download_outlined,
                              height: 48,
                              onPressed: _syncing ? null : _sync,
                            ),
                            const SizedBox(height: 6),
                            Center(
                              child: TextButton(
                                onPressed: _syncing ? null : _skip,
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.dim,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  minimumSize: const Size(0, 34),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text(
                                  'Explorar con los datos incluidos',
                                  style: TextStyle(
                                    fontSize: 12,
                                    decoration: TextDecoration.underline,
                                    decorationColor: AppColors.dim,
                                  ),
                                ),
                              ),
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                _error!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  height: 1.45,
                                  color: Color(0xFFB3261E),
                                ),
                              ),
                            ],
                            const SizedBox(height: 14),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.only(top: 2),
                                  child: Icon(
                                    Icons.lock_outline,
                                    size: 14,
                                    color: AppColors.dim,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text(
                                    'Tus coordenadas y la brújula se procesan '
                                    'en el dispositivo. No se envía tu ubicación '
                                    'a ningún servidor.',
                                    style: TextStyle(
                                      fontSize: 11,
                                      height: 1.55,
                                      color: AppColors.dim,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                TextButton(
                                  onPressed: () => showCredits(context),
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppColors.dim,
                                    padding: EdgeInsets.zero,
                                    minimumSize: const Size(0, 30),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: const Text(
                                    'Créditos',
                                    style: TextStyle(
                                      fontSize: 11,
                                      decoration: TextDecoration.underline,
                                      decorationColor: AppColors.dim,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  'PROTOTIPO v0.1',
                                  style: AppTheme.mono(
                                    size: 9.5,
                                    color: AppColors.labelDim,
                                    letterSpacing: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _BrandRow extends StatelessWidget {
  const _BrandRow({required this.lastSync});

  final DateTime? lastSync;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: const BoxDecoration(
            color: AppColors.accent,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'UTHMAP',
          style: AppTheme.mono(
            size: 12,
            weight: FontWeight.w700,
            color: AppColors.ink,
            letterSpacing: 2.4,
          ),
        ),
        const Spacer(),
        Text(
          lastSync == null ? 'CAMPUS NORTE' : 'SINCRONIZADO',
          style: AppTheme.mono(
            size: 9.5,
            color: AppColors.dim,
            letterSpacing: 1.4,
          ),
        ),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.index,
    required this.title,
    required this.body,
    this.last = false,
  });

  final String index;
  final String title;
  final String body;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 30,
            child: Text(
              index,
              style: AppTheme.mono(
                size: 10.5,
                color: AppColors.accent,
                letterSpacing: 0.6,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w500,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.45,
                    color: AppColors.dim,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CompassMark extends StatelessWidget {
  const _CompassMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _CompassPainter()),
    );
  }
}

class _CompassPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = AppColors.line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    canvas.drawCircle(
      center,
      radius * 0.72,
      Paint()
        ..color = AppColors.lineSoft
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    for (var i = 0; i < 12; i++) {
      final angle = i * math.pi / 6;
      final inner =
          center + Offset(math.sin(angle), -math.cos(angle)) * radius * 0.86;
      final outer =
          center + Offset(math.sin(angle), -math.cos(angle)) * radius * 0.94;
      canvas.drawLine(
        inner,
        outer,
        Paint()
          ..color = i % 3 == 0 ? AppColors.dim : AppColors.line
          ..strokeWidth = 1,
      );
    }

    final needle = Path()
      ..moveTo(center.dx, center.dy - radius * 0.62)
      ..lineTo(center.dx + radius * 0.16, center.dy)
      ..lineTo(center.dx, center.dy + radius * 0.28)
      ..lineTo(center.dx - radius * 0.16, center.dy)
      ..close();
    canvas.drawPath(needle, Paint()..color = AppColors.accent);

    canvas.drawCircle(center, radius * 0.08, Paint()..color = AppColors.page);
    canvas.drawCircle(
      center,
      radius * 0.08,
      Paint()
        ..color = AppColors.ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
