import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config/app_config.dart';
import '../theme/app_colors.dart';

/// The "First Taxis" wordmark: heavy black lettering on a rounded yellow
/// plate. Scales with [height]; used on splash, onboarding and auth screens.
class BrandWordmark extends StatelessWidget {
  const BrandWordmark({super.key, this.height = 48, this.label});

  /// Plate height; the text and padding scale from it.
  final double height;

  /// Overrides the brand name (defaults to the configured brand).
  final String? label;

  @override
  Widget build(BuildContext context) {
    final text = label ?? AppConfig.fromEnvironment().brandName;
    // Row(min) keeps the plate shrink-wrapped to the text instead of
    // stretching to the parent's width.
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [_plate(text)],
    );
  }

  Widget _plate(String text) {
    return Container(
      height: height,
      padding: EdgeInsets.symmetric(horizontal: height * 0.38),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.brand,
        borderRadius: BorderRadius.circular(height * 0.22),
      ),
      child: Text(
        text,
        maxLines: 1,
        style: GoogleFonts.outfit(
          fontSize: height * 0.62,
          fontWeight: FontWeight.w800,
          height: 1,
          letterSpacing: -0.5,
          color: Colors.black,
        ),
      ),
    );
  }
}
