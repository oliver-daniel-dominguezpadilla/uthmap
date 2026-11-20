import 'package:flutter/material.dart';

import '../theme.dart';

/// Texto exacto del CTA del wireframe definitivo.
const String kVideoCta = '[ REPRODUCIR RECORRIDO EN VIDEO — MP4 ]';

class BlackButton extends StatelessWidget {
  const BlackButton({
    super.key,
    required this.label,
    this.onPressed,
    this.height = 42,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final double height;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return SizedBox(
      width: double.infinity,
      height: height,
      child: Material(
        color: enabled ? AppColors.cta : AppColors.labelDim,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 16, color: Colors.white),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      maxLines: 1,
                      style: const TextStyle(
                        fontFamily: 'SpaceGrotesk',
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.66,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class OutlineButton extends StatelessWidget {
  const OutlineButton({
    super.key,
    required this.label,
    this.onPressed,
    this.height = 44,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final double height;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: Material(
        color: AppColors.page,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.line),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 16, color: AppColors.ink),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      maxLines: 1,
                      style: const TextStyle(
                        fontFamily: 'SpaceGrotesk',
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.4,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CategoryPill extends StatelessWidget {
  const CategoryPill({super.key, required this.text, required this.active});

  final String text;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: active ? AppColors.greenBg : AppColors.muted,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: AppTheme.mono(
          size: 12,
          color: active ? AppColors.greenFg : AppColors.dim,
        ),
      ),
    );
  }
}

class TinyLabel extends StatelessWidget {
  const TinyLabel(this.text, {super.key, this.color = AppColors.dim});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: AppTheme.mono(
        size: 10,
        weight: FontWeight.w500,
        color: color,
        letterSpacing: 1.8,
      ),
    );
  }
}

class UthSearchField extends StatelessWidget {
  const UthSearchField({
    super.key,
    required this.controller,
    required this.focusNode,
    this.onChanged,
    this.onSubmitted,
    this.hint = 'Escribe un aula, edificio o palabra clave...',
    this.trailing,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final String hint;
  final Widget? trailing;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: focusNode,
      builder: (context, _) {
        final focused = focusNode.hasFocus;
        return AnimatedContainer(
          duration: kFast,
          curve: kEase,
          height: 50,
          decoration: BoxDecoration(
            color: AppColors.page,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: focused ? AppColors.accent : AppColors.lineSoft,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.ink.withValues(alpha: 0.14),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            children: [
              const SizedBox(width: 14),
              const Icon(Icons.search, size: 20, color: AppColors.dim),
              const SizedBox(width: 10),
              Expanded(
                child: Center(
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    autofocus: autofocus,
                    onChanged: onChanged,
                    onSubmitted: onSubmitted,
                    textInputAction: TextInputAction.search,
                    style: const TextStyle(
                      fontFamily: 'SpaceGrotesk',
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: AppColors.ink,
                    ),
                    cursorColor: AppColors.accent,
                    decoration: InputDecoration(
                      isCollapsed: true,
                      border: InputBorder.none,
                      hintText: hint,
                      hintStyle: const TextStyle(
                        fontFamily: 'SpaceGrotesk',
                        fontSize: 12.5,
                        letterSpacing: -0.1,
                        color: AppColors.placeholder,
                      ),
                    ),
                  ),
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 7),
                trailing!,
                const SizedBox(width: 7),
              ] else
                const SizedBox(width: 14),
            ],
          ),
        );
      },
    );
  }
}

class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.tooltip,
    this.size = 40,
    this.borderColor = AppColors.line,
    this.background = AppColors.page,
    this.iconColor = AppColors.ink,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;
  final double size;
  final Color borderColor;
  final Color background;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: background,
      shape: CircleBorder(side: BorderSide(color: borderColor)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, size: size * 0.5, color: iconColor),
        ),
      ),
    );
    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}

class SectionRule extends StatelessWidget {
  const SectionRule({
    super.key,
    this.padding = const EdgeInsets.symmetric(vertical: 18),
  });

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: const Divider(height: 1, color: AppColors.lineSoft),
    );
  }
}
