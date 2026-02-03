import 'package:flutter/material.dart';

class AppTokens {
  AppTokens._();

  // Radii
  static const double radiusSm = 12;
  static const double radiusMd = 16;
  static const double radiusLg = 20;
  static const double radiusXl = 24;

  // Elevation / Shadows
  static List<BoxShadow> softShadow(bool isDark) => [
        BoxShadow(
          color: (isDark ? Colors.black : Colors.black).withValues(alpha: 0.08),
          blurRadius: 18,
          offset: const Offset(0, 10),
        ),
      ];
}

class AppColorsLight {
  static const bg = Color(0xFFF6F8FC);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceMuted = Color(0xFFF2F5FB);
  static const primary = Color(0xFF2563EB);
  static const secondary = Color(0xFF06B6D4);
  static const text = Color(0xFF0B1220);
  static const textMuted = Color(0xFF5B667A);
  static const border = Color(0xFFE2E8F0);
}

class AppColorsDark {
  static const bg = Color(0xFF0B1220);
  static const surface = Color(0xFF0F172A);
  static const surfaceMuted = Color(0xFF0B1A33);
  static const primary = Color(0xFF2563EB);
  static const secondary = Color(0xFF06B6D4);
  static const text = Color(0xFFFFFFFF);
  static const textMuted = Color(0xFFB7C0D0);
  static const border = Color(0xFF1F2937);
}

class AppThemeColors {
  AppThemeColors._();

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color text(BuildContext context) =>
      isDark(context) ? AppColorsDark.text : AppColorsLight.text;

  static Color textMuted(BuildContext context) =>
      isDark(context) ? AppColorsDark.textMuted : AppColorsLight.textMuted;

  static Color surfaceMuted(BuildContext context) =>
      isDark(context) ? AppColorsDark.surfaceMuted : AppColorsLight.surfaceMuted;
}
