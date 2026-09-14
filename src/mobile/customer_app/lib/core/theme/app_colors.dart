import 'package:flutter/material.dart';

/// Colour tokens.
///
/// Brand red is the Red Taxi web brand primary (admin-v2 `--primary: 0 99% 56%`
/// → #FE2020). It replaces the GoRide kit's brand green (`Surface/Buttons/Brand
/// = #0cc25f`). Neutral / surface / stroke tokens mirror the GoRide design
/// system roles so component extraction maps 1:1.
///
/// Do not reference raw hex outside this file — consume via [AppTheme].
abstract final class AppColors {
  // ── Brand ───────────────────────────────────────────────────────────
  static const brand = Color(0xFFFE2020); // Red Taxi red
  static const brandPressed = Color(0xFFD41212);
  static const onBrand = Color(0xFFFFFFFF); // GoRide Text/Buttons/White

  // ── Neutral ramp (GoRide greyscale roles) ───────────────────────────
  static const neutral0 = Color(0xFFFFFFFF);
  static const neutral50 = Color(0xFFF5F5F5); // Stroke Colors/Light 6
  static const neutral100 = Color(0xFFEFEFEF);
  static const neutral200 = Color(0xFFE0E0E0);
  static const neutral300 = Color(0xFFCFCFCF);
  static const neutral400 = Color(0xFF949494); // icon/default/secondary
  static const neutral500 = Color(0xFF6B6B6B);
  static const neutral600 = Color(0xFF4A4A4A);
  static const neutral700 = Color(0xFF2E2E2E);
  static const neutral800 = Color(0xFF1C1C1E);
  static const neutral900 = Color(0xFF0E0E0F);

  // ── Semantic ────────────────────────────────────────────────────────
  static const success = Color(0xFF12B76A);
  static const warning = Color(0xFFF79009);
  static const error = Color(0xFFE5484D);
  static const info = Color(0xFF2E90FA);

  // ── Light scheme roles ──────────────────────────────────────────────
  static const lightBackground = neutral0;
  static const lightSurface = neutral0;
  static const lightSurfaceAlt = neutral50;
  static const lightTextPrimary = neutral900;
  static const lightTextSecondary = neutral400;
  static const lightStroke = neutral200;

  // ── Dark scheme roles ───────────────────────────────────────────────
  static const darkBackground = neutral900;
  static const darkSurface = neutral800;
  static const darkSurfaceAlt = neutral700;
  static const darkTextPrimary = neutral0;
  static const darkTextSecondary = neutral400;
  static const darkStroke = neutral700;

  // ── Disabled text (placeholders / disabled labels) ──────────────────
  static const lightTextDisabled = neutral300; // #CFCFCF
  static const darkTextDisabled = neutral500; // #6B6B6B

  // ── Accent tint (selected / secondary fills, per GoRide) ────────────
  // Light: opaque pale-red wash. Dark: translucent red (~16%) over surface so
  // it composites correctly on the stepped dark fills.
  static const lightAccentTint = Color(0xFFFFE9E9);
  static const darkAccentTint = Color(0x29FE2020); // #FE2020 @ ~16% alpha

  // ── Map overlays (both themes) — all the brand red ──────────────────
  static const mapRoute = brand; // trip route polyline
  static const mapPin = brand; // driver / pickup / destination teardrops
  static const mapLocationDot = brand; // current-location dot + halo
}
