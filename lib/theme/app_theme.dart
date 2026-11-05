import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_theme_extensions.dart';
import 'app_tokens.dart';

/// Builds the app theme from the design tokens.
///
/// Set [useGoogleFonts] to false in widget tests, where fonts cannot be fetched.
ThemeData buildAppTheme({bool useGoogleFonts = true}) {
  TextStyle serif(TextStyle style) =>
      useGoogleFonts ? GoogleFonts.sourceSerif4(textStyle: style) : style;
  TextStyle sans(TextStyle style) =>
      useGoogleFonts ? GoogleFonts.inter(textStyle: style) : style;
  TextStyle mono(TextStyle style) =>
      useGoogleFonts ? GoogleFonts.jetBrainsMono(textStyle: style) : style;

  const scheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppPalette.primary,
    onPrimary: AppPalette.onPrimary,
    primaryContainer: AppPalette.primaryContainer,
    onPrimaryContainer: AppPalette.onPrimaryContainer,
    secondary: AppPalette.primary,
    onSecondary: AppPalette.onPrimary,
    error: AppPalette.error,
    onError: AppPalette.onPrimary,
    errorContainer: AppPalette.errorContainer,
    onErrorContainer: AppPalette.error,
    surface: AppPalette.surface,
    onSurface: AppPalette.textPrimary,
    onSurfaceVariant: AppPalette.textSecondary,
    surfaceContainer: AppPalette.surfaceContainer,
    surfaceContainerHigh: AppPalette.surfaceContainerHigh,
    outline: AppPalette.outline,
    outlineVariant: AppPalette.outlineVariant,
  );

  final textTheme = TextTheme(
    headlineLarge: serif(
      const TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        height: 1.25,
        color: AppPalette.textPrimary,
      ),
    ),
    headlineMedium: serif(
      const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: AppPalette.textPrimary,
      ),
    ),
    titleLarge: serif(
      const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: AppPalette.textPrimary,
      ),
    ),
    titleMedium: sans(
      const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.4,
        color: AppPalette.textPrimary,
      ),
    ),
    bodyLarge: sans(
      const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: AppPalette.textPrimary,
      ),
    ),
    bodyMedium: sans(
      const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.45,
        color: AppPalette.textSecondary,
      ),
    ),
    labelLarge: sans(
      const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.4,
        color: AppPalette.textPrimary,
      ),
    ),
    labelMedium: sans(
      const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
        color: AppPalette.textSecondary,
      ),
    ),
    labelSmall: sans(
      const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppPalette.textPrimary,
      ),
    ),
  );

  final inputBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppRadius.md),
    borderSide: const BorderSide(color: AppPalette.outline),
  );
  final buttonShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AppRadius.md),
  );
  const buttonPadding = EdgeInsets.symmetric(
    horizontal: AppSpacing.md,
    vertical: AppSpacing.sm,
  );
  const minButtonSize = Size(AppSizes.minTap, AppSizes.minTap);

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    textTheme: textTheme,
    scaffoldBackgroundColor: AppPalette.background,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    extensions: [
      StatusColors.standard,
      AppTextExtras(
        mono: mono(
          const TextStyle(
            fontSize: 13,
            height: 1.5,
            color: AppPalette.textSecondary,
          ),
        ),
        muted: AppPalette.textMuted,
      ),
    ],
    appBarTheme: AppBarTheme(
      backgroundColor: AppPalette.surface,
      foregroundColor: AppPalette.textPrimary,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 1,
      centerTitle: false,
      titleTextStyle: textTheme.titleLarge,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: minButtonSize,
        padding: buttonPadding,
        shape: buttonShape,
        textStyle: textTheme.labelLarge,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: minButtonSize,
        padding: buttonPadding,
        foregroundColor: AppPalette.primary,
        side: const BorderSide(color: AppPalette.primary, width: 1.5),
        shape: buttonShape,
        textStyle: textTheme.labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: minButtonSize,
        foregroundColor: AppPalette.primary,
        shape: buttonShape,
        textStyle: textTheme.labelLarge,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppPalette.surface,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      border: inputBorder,
      enabledBorder: inputBorder,
      focusedBorder: inputBorder.copyWith(
        borderSide: const BorderSide(color: AppPalette.primary, width: 2),
      ),
      errorBorder: inputBorder.copyWith(
        borderSide: const BorderSide(color: AppPalette.error),
      ),
      focusedErrorBorder: inputBorder.copyWith(
        borderSide: const BorderSide(color: AppPalette.error, width: 2),
      ),
      hintStyle: textTheme.bodyMedium?.copyWith(color: AppPalette.textMuted),
      labelStyle: textTheme.bodyMedium,
      helperStyle: textTheme.bodyMedium,
      errorStyle: textTheme.bodyMedium?.copyWith(color: AppPalette.error),
      errorMaxLines: 2,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppPalette.surface,
      indicatorColor: AppPalette.primaryContainer,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => textTheme.labelSmall?.copyWith(
          color: states.contains(WidgetState.selected)
              ? AppPalette.primary
              : AppPalette.textSecondary,
        ),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppPalette.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      titleTextStyle: textTheme.titleLarge,
      contentTextStyle: textTheme.bodyMedium,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppPalette.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: AppPalette.outlineVariant,
      space: 1,
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppPalette.primary,
      linearTrackColor: AppPalette.surfaceContainerHigh,
    ),
  );
}
