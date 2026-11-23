import 'dart:async';

import 'package:flutter/material.dart';

import '../../state/navigation_controller.dart';
import '../theme.dart';
import 'primitives.dart';

class SensorPanel extends StatelessWidget {
  const SensorPanel({
    super.key,
    required this.controller,
    this.compact = false,
    this.advanced = true,
    this.onOpenAdvanced,
  });

  final NavigationController controller;
  final bool compact;

  /// Muestra el selector de fuente (simulado/real) y los estados de error.
  /// En el panel lateral se oculta para respetar el wireframe.
  final bool advanced;
  final VoidCallback? onOpenAdvanced;

  @override
  Widget build(BuildContext context) {
    final real = controller.realSensors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        TinyLabel(real ? 'Sensores del dispositivo' : 'Sensores simulados'),
        const SizedBox(height: 10),
        Row(
          children: [
            const Text(
              'Orientación',
              style: TextStyle(fontSize: 12, color: AppColors.dim),
            ),
            const SizedBox(width: 6),
            Text(
              '${controller.rawHeading.round()}°',
              style: const TextStyle(fontSize: 12, color: AppColors.ink),
            ),
          ],
        ),
        Slider(
          min: 0,
          max: 359,
          value: controller.rawHeading.clamp(0, 359),
          onChanged: real ? null : controller.setHeading,
        ),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            _PanelAction(
              label: controller.walking ? 'Pausar' : 'Caminar',
              onTap: real ? null : controller.toggleWalking,
            ),
            _PanelAction(
              label: 'Alinear',
              onTap: real ? null : controller.alignHeading,
            ),
            _PanelAction(
              label: 'Reiniciar',
              onTap: () {
                if (real) unawaited(controller.setRealSensors(false));
                controller.resetDemo();
              },
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          'Aviso ≤ 20 m. Llegada ≤ 15 m. El vector apunta al acceso; el cono azul muestra hacia dónde mira el teléfono.',
          style: TextStyle(
            fontSize: compact ? 12 : 11,
            height: 1.6,
            color: AppColors.dim,
          ),
        ),
        if (!advanced) ...[
          const SizedBox(height: 12),
          _PanelAction(label: 'Ajustes de sensores', onTap: onOpenAdvanced),
        ],
        if (advanced) ...[
          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.lineSoft),
          const SizedBox(height: 16),
          const TinyLabel('Fuente'),
          const SizedBox(height: 8),
          _Segmented(
            options: const ['Simulado', 'Real'],
            selected: real ? 1 : 0,
            onChanged: (index) =>
                unawaited(controller.setRealSensors(index == 1)),
          ),
          const SizedBox(height: 14),
          if (!real) ...[
            const TinyLabel('GPS'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _MiniChip(
                  label: 'OK',
                  selected: controller.gpsSimulation == GpsSimulation.ok,
                  onTap: () => controller.setGpsSimulation(GpsSimulation.ok),
                ),
                _MiniChip(
                  label: 'Denegado',
                  selected: controller.gpsSimulation == GpsSimulation.denied,
                  onTap: () =>
                      controller.setGpsSimulation(GpsSimulation.denied),
                ),
                _MiniChip(
                  label: 'Apagado',
                  selected: controller.gpsSimulation == GpsSimulation.disabled,
                  onTap: () =>
                      controller.setGpsSimulation(GpsSimulation.disabled),
                ),
                _MiniChip(
                  label: 'Sin señal',
                  selected: controller.gpsSimulation == GpsSimulation.noSignal,
                  onTap: () =>
                      controller.setGpsSimulation(GpsSimulation.noSignal),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _CheckRow(
              label: 'Brújula sin calibrar',
              value: controller.compassUncalibrated,
              onChanged: controller.setCompassUncalibrated,
            ),
          ] else ...[
            const TinyLabel('Estado real'),
            const SizedBox(height: 8),
            Text(
              controller.gpsMessage ??
                  'GPS activo · precisión ${controller.accuracyM?.round() ?? '—'} m',
              style: const TextStyle(
                fontSize: 12,
                height: 1.45,
                color: AppColors.dim,
              ),
            ),
            if (controller.compassMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                controller.compassMessage!,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.45,
                  color: AppColors.dim,
                ),
              ),
            ],
            const SizedBox(height: 10),
            _PanelAction(
              label: 'Volver a simulado',
              onTap: () => unawaited(controller.setRealSensors(false)),
            ),
          ],
          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.lineSoft),
          const SizedBox(height: 16),
          Row(
            children: [
              const TinyLabel('Declinación'),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _formatDeclination(controller.declinationDeg),
                  style: AppTheme.mono(size: 12, color: AppColors.ink),
                ),
              ),
              _PanelAction(
                label: '−1°',
                onTap: () => unawaited(
                  controller.setDeclinationDeg(controller.declinationDeg - 1),
                ),
              ),
              const SizedBox(width: 12),
              _PanelAction(
                label: '+1°',
                onTap: () => unawaited(
                  controller.setDeclinationDeg(controller.declinationDeg + 1),
                ),
              ),
              const SizedBox(width: 12),
              _PanelAction(
                label: '0',
                onTap: () => unawaited(controller.setDeclinationDeg(0)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            controller.compassAccuracyDeg == null
                ? 'Brújula —'
                : 'Brújula ±${controller.compassAccuracyDeg!.round()}°',
            style: const TextStyle(fontSize: 12, color: AppColors.dim),
          ),
          const SizedBox(height: 12),
          _PanelAction(
            label: 'Ver log',
            onTap: () => unawaited(showSensorLog(context, controller)),
          ),
        ],
      ],
    );
  }
}

/// Declinación con un decimal y signo solo cuando no es cero.
String _formatDeclination(double value) {
  final rounded = (value * 10).round() / 10;
  if (rounded == 0) return '0°';
  final sign = rounded > 0 ? '+' : '−';
  return '$sign${rounded.abs().toStringAsFixed(1)}°';
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: const Color(0xFFD6D4CF),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _PanelAction extends StatelessWidget {
  const _PanelAction({required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        padding: EdgeInsets.zero,
        minimumSize: const Size(0, 24),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        foregroundColor: AppColors.dim,
        disabledForegroundColor: AppColors.line,
        overlayColor: Colors.transparent,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: onTap == null ? AppColors.line : AppColors.dim,
          decoration: TextDecoration.underline,
          decorationColor: onTap == null ? AppColors.line : AppColors.dim,
          decorationStyle: TextDecorationStyle.solid,
        ),
      ),
    );
  }
}

class _Segmented extends StatelessWidget {
  const _Segmented({
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final List<String> options;
  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: AppColors.lineSoft),
      ),
      child: Row(
        children: [
          for (var i = 0; i < options.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(i),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: kFast,
                  curve: kEase,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: selected == i ? AppColors.ink : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    options[i],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: selected == i ? Colors.white : AppColors.dim,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: kFast,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected ? AppColors.accent : AppColors.line,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: selected ? Colors.white : AppColors.dim,
          ),
        ),
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          AnimatedContainer(
            duration: kFast,
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: value ? AppColors.accent : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: value ? AppColors.accent : AppColors.line,
              ),
            ),
            child: value
                ? const Icon(Icons.check, size: 12, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: AppColors.dim),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> showSensorPanel(
  BuildContext context,
  NavigationController controller,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.ink.withValues(alpha: 0.28),
    builder: (sheetContext) {
      return Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.86,
        ),
        decoration: const BoxDecoration(
          color: AppColors.page,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 22),
            child: ListenableBuilder(
              listenable: controller,
              builder: (context, _) => Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SheetHandle(),
                  const SizedBox(height: 18),
                  SensorPanel(controller: controller, compact: true),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// Hoja de depuración con las últimas entradas del log de sensores.
Future<void> showSensorLog(
  BuildContext context,
  NavigationController controller,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.ink.withValues(alpha: 0.28),
    builder: (sheetContext) {
      return Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.70,
        ),
        decoration: const BoxDecoration(
          color: AppColors.page,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 22),
            child: ListenableBuilder(
              listenable: controller,
              builder: (context, _) {
                final lines = controller.sensorLogLines;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SheetHandle(),
                    const SizedBox(height: 18),
                    const TinyLabel('Log de sensores'),
                    const SizedBox(height: 12),
                    Flexible(
                      child: lines.isEmpty
                          ? const Text(
                              'Sin eventos todavía.',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.dim,
                              ),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              padding: EdgeInsets.zero,
                              itemCount: lines.length,
                              separatorBuilder: (context, index) =>
                                  const SizedBox(height: 6),
                              itemBuilder: (context, index) => Text(
                                lines[index],
                                style: AppTheme.mono(
                                  size: 10,
                                  color: AppColors.dim,
                                ),
                              ),
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );
    },
  );
}
