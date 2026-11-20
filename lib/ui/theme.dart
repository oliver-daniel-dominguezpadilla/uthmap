import 'package:flutter/material.dart';

/// Tokens del wireframe definitivo. El documento de arquitectura proponía un
/// tema oscuro, pero el wireframe es la referencia visual acordada.
abstract final class AppColors {
  static const Color page = Color(0xFFFFFFFF);
  static const Color canvas = Color(0xFFF9F8F6);
  static const Color ink = Color(0xFF111317);
  static const Color dim = Color(0xFF6B6F76);
  static const Color line = Color(0xFFE4E2DD);
  static const Color lineSoft = Color(0xFFEFEDE9);
  static const Color accent = Color(0xFF0055FF);
  static const Color muted = Color(0xFFF1EFEB);
  static const Color greenBg = Color(0xFFE8F3EA);
  static const Color greenFg = Color(0xFF2F6B3A);
  static const Color cta = Color(0xFF171717);
  static const Color ctaHover = Color(0xFF262626);
  static const Color placeholder = Color(0xFF7A7E85);
  static const Color path = Color(0xFFD2CFC8);
  static const Color grid = Color(0xFFEEECE7);
  static const Color labelDim = Color(0xFF8A8D93);
}

abstract final class AppTheme {
  static ThemeData get light {
    const text = TextTheme(
      displayLarge: TextStyle(
        fontSize: 46,
        fontWeight: FontWeight.w700,
        height: 1.02,
        letterSpacing: -1.6,
      ),
      displayMedium: TextStyle(
        fontSize: 38,
        fontWeight: FontWeight.w700,
        height: 1.05,
        letterSpacing: -1.2,
      ),
      headlineLarge: TextStyle(
        fontSize: 30,
        fontWeight: FontWeight.w700,
        height: 1.1,
        letterSpacing: -0.8,
      ),
      headlineMedium: TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        height: 1.15,
        letterSpacing: -0.5,
      ),
      titleLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        height: 1.3,
      ),
      bodyLarge: TextStyle(fontSize: 15, height: 1.55),
      bodyMedium: TextStyle(fontSize: 14, height: 1.5),
      bodySmall: TextStyle(fontSize: 12, height: 1.45),
      labelLarge: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.72,
      ),
      labelMedium: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.4,
      ),
      labelSmall: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w500,
        letterSpacing: 1.8,
      ),
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: 'SpaceGrotesk',
      scaffoldBackgroundColor: AppColors.page,
    );

    return base.copyWith(
      colorScheme: const ColorScheme.light(
        primary: AppColors.accent,
        onPrimary: Colors.white,
        secondary: AppColors.ink,
        onSecondary: Colors.white,
        surface: AppColors.page,
        onSurface: AppColors.ink,
        error: Color(0xFFB3261E),
        onError: Colors.white,
      ),
      textTheme: text.apply(
        fontFamily: 'SpaceGrotesk',
        bodyColor: AppColors.ink,
        displayColor: AppColors.ink,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.line,
        thickness: 1,
        space: 1,
      ),
      iconTheme: const IconThemeData(color: AppColors.ink, size: 24),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: AppColors.accent,
        selectionColor: AppColors.accent.withValues(alpha: 0.18),
        selectionHandleColor: AppColors.accent,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.accent,
        inactiveTrackColor: AppColors.line,
        thumbColor: AppColors.accent,
        overlayColor: AppColors.accent.withValues(alpha: 0.12),
        trackHeight: 3,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.ink,
          borderRadius: BorderRadius.circular(6),
        ),
        textStyle: const TextStyle(
          fontFamily: 'SpaceGrotesk',
          fontSize: 11,
          color: Colors.white,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.ink,
        contentTextStyle: const TextStyle(
          fontFamily: 'SpaceGrotesk',
          color: Colors.white,
          fontSize: 13,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        insetPadding: const EdgeInsets.all(16),
      ),
    );
  }

  static TextStyle mono({
    double size = 12,
    FontWeight weight = FontWeight.w400,
    Color color = AppColors.ink,
    double? letterSpacing,
    double? height,
  }) {
    return TextStyle(
      fontFamily: 'SpaceMono',
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );
  }
}

/// Movimiento de 150 ms ease-out, como el wireframe. El sheet usa 250 ms.
const Duration kFast = Duration(milliseconds: 150);
const Duration kSheet = Duration(milliseconds: 250);
const Curve kEase = Curves.easeOut;
