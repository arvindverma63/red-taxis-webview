import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// Single source of truth for [ThemeData]. Every widget styles via
/// `Theme.of(context)` — never raw colours or text styles. Light + dark are
/// built from the same tokens so a brand change is a token change.
abstract final class AppTheme {
  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isLight = brightness == Brightness.light;

    final scheme = ColorScheme(
      brightness: brightness,
      primary: AppColors.brand,
      onPrimary: AppColors.onBrand,
      secondary: AppColors.brand,
      onSecondary: AppColors.onBrand,
      error: AppColors.error,
      onError: AppColors.onBrand,
      surface: isLight ? AppColors.lightSurface : AppColors.darkSurface,
      onSurface:
          isLight ? AppColors.lightTextPrimary : AppColors.darkTextPrimary,
      surfaceContainerHighest:
          isLight ? AppColors.lightSurfaceAlt : AppColors.darkSurfaceAlt,
      outline: isLight ? AppColors.lightStroke : AppColors.darkStroke,
    );

    final textPrimary =
        isLight ? AppColors.lightTextPrimary : AppColors.darkTextPrimary;
    final textSecondary =
        isLight ? AppColors.lightTextSecondary : AppColors.darkTextSecondary;
    final textDisabled =
        isLight ? AppColors.lightTextDisabled : AppColors.darkTextDisabled;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor:
          isLight ? AppColors.lightBackground : AppColors.darkBackground,
      textTheme: AppTypography.textTheme(textPrimary, textSecondary),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: AppTypography.titleLarge.copyWith(color: textPrimary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.brand,
          foregroundColor: AppColors.onBrand,
          disabledBackgroundColor: AppColors.neutral300,
          minimumSize: const Size.fromHeight(52),
          elevation: 0,
          textStyle: AppTypography.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          minimumSize: const Size.fromHeight(52),
          side: BorderSide(color: scheme.outline, width: AppStroke.thin),
          textStyle: AppTypography.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: textPrimary,
          textStyle: AppTypography.labelMedium.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isLight ? AppColors.lightSurface : AppColors.darkSurfaceAlt,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: AppSpacing.lg),
        hintStyle: AppTypography.bodyMedium.copyWith(color: textDisabled),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: scheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: scheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: textPrimary, width: 1.5),
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          // Light separates cards with a hairline border; dark uses stepped
          // fill elevation (surface lighter than background) and NO border.
          side: isLight
              ? BorderSide(color: scheme.outline, width: AppStroke.thin)
              : BorderSide.none,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outline,
        thickness: AppStroke.thin,
        space: AppSpacing.lg,
      ),
      // Text caret + selection use the brand red, not the Material default —
      // keeps inputs on-brand in both themes (kills the stray green caret).
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: textPrimary,
        selectionHandleColor: AppColors.brandPressed,
        selectionColor: const Color(0x66FFD500), // brand @ ~40%
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.brand
              : Colors.transparent,
        ),
        checkColor: const WidgetStatePropertyAll(AppColors.onBrand),
        side: BorderSide(color: textPrimary, width: 1.5),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.brand,
      ),
    );
  }
}
