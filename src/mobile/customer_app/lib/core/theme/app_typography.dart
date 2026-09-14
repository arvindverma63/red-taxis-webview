import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Type scale in Urbanist (the GoRide kit typeface), served via google_fonts.
///
/// Reference token (GoRide Primary Button): `Urbanist/Large/bold` =
/// size 16, weight 700, lineHeight 1.6, letterSpacing 0.2. The scale below
/// extends that into a full [TextTheme]. Colour is applied by [AppTheme] per
/// brightness — these carry size/weight/spacing only.
abstract final class AppTypography {
  static TextStyle _u(double size, FontWeight weight,
          {double height = 1.4, double spacing = 0}) =>
      GoogleFonts.urbanist(
        fontSize: size,
        fontWeight: weight,
        height: height,
        letterSpacing: spacing,
      );

  // Display / headings
  static TextStyle get displayLarge => _u(32, FontWeight.w700, height: 1.25);
  static TextStyle get displayMedium => _u(28, FontWeight.w700, height: 1.3);
  static TextStyle get headlineLarge => _u(24, FontWeight.w700, height: 1.3);
  static TextStyle get headlineMedium => _u(20, FontWeight.w600, height: 1.35);
  static TextStyle get titleLarge => _u(18, FontWeight.w600, height: 1.4);
  static TextStyle get titleMedium => _u(16, FontWeight.w600, height: 1.5);

  // Body
  static TextStyle get bodyLarge => _u(16, FontWeight.w500, height: 1.5);
  static TextStyle get bodyMedium => _u(14, FontWeight.w500, height: 1.5);
  static TextStyle get bodySmall => _u(12, FontWeight.w500, height: 1.45);

  // Button / label (GoRide Urbanist/Large/bold)
  static TextStyle get labelLarge =>
      _u(16, FontWeight.w700, height: 1.6, spacing: 0.2);
  static TextStyle get labelMedium => _u(14, FontWeight.w600, height: 1.4);
  static TextStyle get labelSmall => _u(12, FontWeight.w600, height: 1.4);

  static TextTheme textTheme(Color primary, Color secondary) => TextTheme(
        displayLarge: displayLarge.copyWith(color: primary),
        displayMedium: displayMedium.copyWith(color: primary),
        headlineLarge: headlineLarge.copyWith(color: primary),
        headlineMedium: headlineMedium.copyWith(color: primary),
        titleLarge: titleLarge.copyWith(color: primary),
        titleMedium: titleMedium.copyWith(color: primary),
        bodyLarge: bodyLarge.copyWith(color: primary),
        bodyMedium: bodyMedium.copyWith(color: primary),
        bodySmall: bodySmall.copyWith(color: secondary),
        labelLarge: labelLarge.copyWith(color: primary),
        labelMedium: labelMedium.copyWith(color: primary),
        labelSmall: labelSmall.copyWith(color: secondary),
      );
}
