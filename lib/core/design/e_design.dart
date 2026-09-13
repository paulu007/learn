import 'package:flutter/material.dart';

/// E design tokens: the single source of truth for spacing, radii, motion,
/// and shared brand colors (spec §5). All widgets must use these instead of
/// hard-coded magic numbers so every screen feels like one product.
abstract final class ESpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
}

abstract final class ERadii {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double pill = 999;
}

/// Brand accent colors shared by the light and dark themes.
/// Feedback colors for correct/incorrect stay in [AppConstants]; these are
/// for gamification surfaces (streak, XP, highlights).
abstract final class EColors {
  static const streak = Color(0xFFF59E0B);
  static const xp = Color(0xFF8B5CF6);
  static const success = Color(0xFF16A34A);
  static const danger = Color(0xFFDC2626);

  /// Mockup surfaces: dark navy cards, sun-yellow streak pills,
  /// leaf-green confirms, sky-blue primary gradient.
  static const ink = Color(0xFF182032);
  static const inkSoft = Color(0xFF232D45);
  static const sun = Color(0xFFFFC531);
  static const leaf = Color(0xFF22C55E);
  static const sky = Color(0xFF2F7CF6);
  static const skySoft = Color(0xFF5B9BFF);
}

/// Motion durations. All entrance/feedback animation must go through
/// [of] so the OS "reduced motion" setting is honored (spec §6, §48).
abstract final class EMotion {
  static const fast = Duration(milliseconds: 120);
  static const medium = Duration(milliseconds: 220);
  static const slow = Duration(milliseconds: 350);

  /// Returns [d], or zero when the device requests reduced motion.
  static Duration of(BuildContext context, Duration d) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : d;
}

/// Text-first feedback labels. Important information is never communicated
/// through color alone (spec §6): every colored state pairs with one of
/// these explicit text marks.
abstract final class EFeedbackText {
  static const correct = 'Correct ✓';
  static const incorrect = 'Incorrect ✕';
  static const retry = 'Try Again ↻';
  static const completed = 'Completed ✓';
}
