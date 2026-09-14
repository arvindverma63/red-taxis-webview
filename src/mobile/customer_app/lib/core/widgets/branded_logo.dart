import 'package:flutter/material.dart';
import '../theme/theme.dart';

class BrandedLogo extends StatelessWidget {
  final TenantBranding branding;
  final double size;
  final bool isDark;

  const BrandedLogo({
    super.key,
    required this.branding,
    this.size = 40.0,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    final logoUrl = isDark ? (branding.logoDarkUrl ?? branding.logoUrl) : branding.logoUrl;

    if (logoUrl != null && logoUrl.isNotEmpty) {
      return Image.network(
        logoUrl,
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => _buildAssetFallback(),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return SizedBox(
            width: size,
            height: size,
            child: Center(
              child: SizedBox(
                width: size * 0.5,
                height: size * 0.5,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: branding.primaryColor,
                ),
              ),
            ),
          );
        },
      );
    }

    return _buildAssetFallback();
  }

  Widget _buildAssetFallback() {
    return Image.asset(
      'assets/images/logo.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) => _buildIconFallback(),
    );
  }

  Widget _buildIconFallback() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: branding.primaryColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Center(
        child: Icon(
          Icons.local_taxi_rounded,
          size: size * 0.6,
          color: branding.primaryColor,
        ),
      ),
    );
  }
}
