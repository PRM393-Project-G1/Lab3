import 'package:flutter/material.dart';

/// Raw palette of the "Academic Verifier" design system (Figma page 04).
/// Only `lib/theme/` reads this; everything else goes through the theme.
abstract final class AppPalette {
  static const primary = Color(0xFF1E3A8A);
  static const onPrimary = Color(0xFFFFFFFF);
  static const primaryContainer = Color(0xFFDCE1FF);
  static const onPrimaryContainer = Color(0xFF00164E);

  static const background = Color(0xFFF8FAFC);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceContainer = Color(0xFFF1F5F9);
  static const surfaceContainerHigh = Color(0xFFE2E8F0);
  // 4.55:1 on background, so input borders stay visible.
  static const outline = Color(0xFF64748B);
  static const outlineVariant = Color(0xFFE2E8F0);

  static const textPrimary = Color(0xFF0F172A);
  static const textSecondary = Color(0xFF475569);
  // Not on surfaceContainer, where it only reaches 4.34:1.
  static const textMuted = Color(0xFF64748B);

  static const hallucinated = Color(0xFF7E22CE);
  static const hallucinatedContainer = Color(0xFFFAF5FF);
  static const hallucinatedBorder = Color(0xFFE9D5FF);

  static const error = Color(0xFFB91C1C);
  static const errorContainer = Color(0xFFFEF2F2);
  static const errorBorder = Color(0xFFFECACA);

  // Amber #D97706 fails 4.5:1 for text, so it is only used for icons and bars.
  static const warning = Color(0xFF92400E);
  static const warningIcon = Color(0xFFD97706);
  static const warningContainer = Color(0xFFFFFBEB);
  static const warningBorder = Color(0xFFFDE68A);

  static const verified = Color(0xFF15803D);
  static const verifiedContainer = Color(0xFFF0FDF4);
  static const verifiedBorder = Color(0xFFBBF7D0);

  static const unverified = Color(0xFF475569);
  static const unverifiedContainer = Color(0xFFF8FAFC);
  static const unverifiedBorder = Color(0xFFE2E8F0);

  // Knowledge graph. Topic, author, is-a and part-of pass the colour-blind
  // checks as a set on the background; every relation also has its own line.
  static const graphTopic = Color(0xFF3355D1);
  static const graphAuthor = Color(0xFF0B9A8D);
  static const graphEdge = Color(0xFFA3B1C6);
  static const graphIsA = Color(0xFFD9541E);
  static const graphPartOf = Color(0xFFA8338F);
  static const graphSameAs = Color(0xFF334155);
}

abstract final class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;

  /// Horizontal page margin.
  static const page = md;
}

abstract final class AppRadius {
  static const sm = 6.0; // chips
  static const md = 8.0; // buttons, inputs
  static const lg = 12.0; // cards
  static const xl = 24.0; // dialogs, sheets
}

abstract final class AppSizes {
  /// Minimum touch target.
  static const minTap = 48.0;
  static const inputHeight = 56.0;
  static const iconSm = 16.0;
  static const iconMd = 24.0;
  static const iconLg = 44.0;
  static const statusBarHeight = 8.0;
  static const stateIconCircle = 96.0;
  static const unreadDot = 10.0;
  static const spinnerSm = 18.0;
}

abstract final class AppElevation {
  static const card = [
    BoxShadow(color: Color(0x0D0F172A), blurRadius: 3, offset: Offset(0, 1)),
  ];
  static const raised = [
    BoxShadow(color: Color(0x140F172A), blurRadius: 12, offset: Offset(0, 4)),
  ];
}
