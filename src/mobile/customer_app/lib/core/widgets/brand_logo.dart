import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Renders the First Taxis brand logo asset with fallback.
///
/// Supports customizable dimensions, border radius, background, and drop shadow.
class BrandLogo extends StatelessWidget {
  const BrandLogo({
    super.key,
    this.size = 40,
    this.borderRadius,
    this.backgroundColor,
    this.showBorder = false,
    this.borderColor,
    this.showShadow = false,
    this.padding,
    this.fit = BoxFit.contain,
  });

  /// The width and height of the logo container.
  final double size;

  /// Custom border radius for the logo container.
  final BorderRadius? borderRadius;

  /// Optional background color. Defaults to white for high contrast on the logo.
  final Color? backgroundColor;

  /// Whether to render a subtle border around the logo.
  final bool showBorder;

  /// Border color if [showBorder] is true.
  final Color? borderColor;

  /// Whether to render a soft ambient shadow.
  final bool showShadow;

  /// Inner padding around the logo image.
  final EdgeInsetsGeometry? padding;

  /// How the image fits inside the bounds.
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final effectiveRadius = borderRadius ?? BorderRadius.circular(AppRadius.md);
    final effectiveBg = backgroundColor ?? Colors.white;

    return Container(
      width: size,
      height: size,
      padding: padding ?? EdgeInsets.all(size * 0.1),
      decoration: BoxDecoration(
        color: effectiveBg,
        borderRadius: effectiveRadius,
        border: showBorder
            ? Border.all(
                color: borderColor ?? AppColors.neutral200,
                width: 1,
              )
            : null,
        boxShadow: showShadow
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: AppColors.brand.withValues(alpha: 0.12),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular((effectiveRadius.topLeft.x - 2).clamp(0, 100)),
        child: Image.asset(
          'assets/images/logo.png',
          fit: fit,
          errorBuilder: (context, error, stackTrace) {
            return Center(
              child: Icon(
                Icons.local_taxi_rounded,
                size: size * 0.6,
                color: AppColors.brand,
              ),
            );
          },
        ),
      ),
    );
  }
}
