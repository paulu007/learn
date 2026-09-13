import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

/// Light and dark themes. The dark theme is a designed palette, not an
/// inverted light theme. Both use rounded cards and large touch targets.
class AppTheme {
  static const _radius = 16.0;

  static ThemeData light(double textScale) {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppConstants.actionBlue,
      brightness: Brightness.light,
    );
    return _base(scheme, textScale);
  }

  static ThemeData dark(double textScale) {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppConstants.actionBlue,
      brightness: Brightness.dark,
    ).copyWith(
      surface: const Color(0xFF161A22),
      surfaceContainerLow: const Color(0xFF1D2330),
      surfaceContainerHighest: const Color(0xFF262E40),
    );
    return _base(scheme, textScale);
  }

  static ThemeData _base(ColorScheme scheme, double textScale) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radius),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 52),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_radius),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_radius),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
    ).copyWith(
      // Apply the user's font-size choice app-wide.
      textTheme: ThemeData.light().textTheme.apply(fontSizeFactor: textScale),
    );
  }
}
