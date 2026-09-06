import 'package:flutter/material.dart';

/// The single source of colour and type for every Flutter surface in the game.
class FindoColors {
  const FindoColors._();

  static const background = Color(0xFF141824);
  static const surface = Color(0xFF1E2333);
  static const surfaceRaised = Color(0xFF2A3145);
  static const primary = Color(0xFFFFC53D);
  static const onPrimary = Color(0xFF221A00);
  static const accent = Color(0xFF4CC9F0);
  static const success = Color(0xFF4ADE80);
  static const danger = Color(0xFFF87171);
  static const textPrimary = Color(0xFFF5F7FA);
  static const textMuted = Color(0xFFA5AEC2);
  static const locked = Color(0xFF39405A);
}

/// Corner radii and paddings reused across overlays, so panels look related.
class FindoMetrics {
  const FindoMetrics._();

  static const radiusPanel = 24.0;
  static const radiusControl = 16.0;
  static const gutter = 16.0;
  static const gutterTight = 10.0;
}

ThemeData buildFindoTheme() {
  const scheme = ColorScheme.dark(
    primary: FindoColors.primary,
    onPrimary: FindoColors.onPrimary,
    secondary: FindoColors.accent,
    onSecondary: FindoColors.onPrimary,
    surface: FindoColors.surface,
    onSurface: FindoColors.textPrimary,
    error: FindoColors.danger,
    onError: FindoColors.textPrimary,
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: FindoColors.background,
    fontFamily: 'Findo',
  );

  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: FindoColors.textPrimary,
      displayColor: FindoColors.textPrimary,
    ),
    dialogTheme: base.dialogTheme.copyWith(
      backgroundColor: FindoColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(FindoMetrics.radiusPanel),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: FindoColors.primary,
        foregroundColor: FindoColors.onPrimary,
        minimumSize: const Size(0, 52),
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FindoMetrics.radiusControl),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: FindoColors.textPrimary,
        minimumSize: const Size(0, 52),
        side: const BorderSide(color: FindoColors.surfaceRaised, width: 2),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FindoMetrics.radiusControl),
        ),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? FindoColors.onPrimary
            : FindoColors.textMuted,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? FindoColors.primary
            : FindoColors.surfaceRaised,
      ),
    ),
  );
}
