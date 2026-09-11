import 'package:flutter/material.dart';
import 'package:driver_app/core/theme/theme.dart';

/// A robust branded logo widget with 3-tier progressive fallback:
/// 1. Remote tenant logo URL (`logoLightUrl` / `logoDarkUrl` / `symbolUrl`)
/// 2. Local bundled asset logo (`assets/images/logo.png`)
/// 3. Standardized Material vector icon (`Icons.local_taxi_rounded` / `Icons.domain_rounded`)
class BrandedLogo extends StatelessWidget {
  final TenantBranding? branding;
  final double? size;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BoxShape shape;
  final BorderRadius? borderRadius;
  final Color? backgroundColor;
  final EdgeInsetsGeometry? padding;
  final Color? fallbackIconColor;
  final IconData fallbackIcon;
  final bool isDark;
  final String? customLogoUrl;
  final Widget? customFallback;

  const BrandedLogo({
    super.key,
    this.branding,
    this.size,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.shape = BoxShape.rectangle,
    this.borderRadius,
    this.backgroundColor,
    this.padding,
    this.fallbackIconColor,
    this.fallbackIcon = Icons.local_taxi_rounded,
    this.isDark = false,
    this.customLogoUrl,
    this.customFallback,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveWidth = width ?? size ?? 48.0;
    final effectiveHeight = height ?? size ?? 48.0;
    final brand = branding ?? TenantBranding.defaultFirstTaxis();
    final primary = fallbackIconColor ?? brand.primaryColor;

    final logoUrl = customLogoUrl ??
        (isDark ? brand.logoDarkUrl : brand.logoLightUrl) ??
        brand.logoLightUrl ??
        brand.logoDarkUrl ??
        brand.symbolUrl;

    Widget imageWidget;

    if (logoUrl != null &&
        logoUrl.trim().isNotEmpty &&
        (logoUrl.startsWith('http://') || logoUrl.startsWith('https://'))) {
      imageWidget = Image.network(
        logoUrl.trim(),
        width: effectiveWidth,
        height: effectiveHeight,
        fit: fit,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return _buildDefaultAsset(effectiveWidth, effectiveHeight, primary);
        },
        errorBuilder: (context, error, stackTrace) {
          return _buildDefaultAsset(effectiveWidth, effectiveHeight, primary);
        },
      );
    } else {
      imageWidget = _buildDefaultAsset(effectiveWidth, effectiveHeight, primary);
    }

    Widget content = Container(
      width: effectiveWidth,
      height: effectiveHeight,
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: shape,
        borderRadius: shape == BoxShape.circle ? null : borderRadius,
      ),
      child: imageWidget,
    );

    if (shape == BoxShape.circle) {
      return ClipOval(child: content);
    } else if (borderRadius != null) {
      return ClipRRect(borderRadius: borderRadius!, child: content);
    }

    return content;
  }

  Widget _buildDefaultAsset(double w, double h, Color primary) {
    return Image.asset(
      'assets/images/logo.png',
      width: w,
      height: h,
      fit: fit,
      errorBuilder: (context, error, stackTrace) {
        return customFallback ??
            Center(
              child: Icon(
                fallbackIcon,
                color: primary,
                size: (w < h ? w : h) * 0.65,
              ),
            );
      },
    );
  }
}
