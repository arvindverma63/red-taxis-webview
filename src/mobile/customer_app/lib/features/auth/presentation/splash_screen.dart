import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/widgets.dart';
import '../application/auth_controller.dart';

/// Brand load screen. Resolves [splashRedirectProvider] (which restores any
/// stored session) and routes to Home, Onboarding (first run) or Sign in. Shows
/// a branded mark + spinner while resolving, and an error state with retry if
/// session restore throws unexpectedly.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  bool _navigated = false;

  void _goTo(String location) {
    if (_navigated || !mounted) return;
    _navigated = true;
    context.go(location);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brand = AppConfig.fromEnvironment().brandName;

    // Navigate once the redirect target resolves; rebuilds are fine because the
    // _navigated guard makes the go() idempotent.
    ref.listen<AsyncValue<String>>(splashRedirectProvider, (_, next) {
      next.whenData(_goTo);
    });

    final redirect = ref.watch(splashRedirectProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: redirect.when(
            loading: () => _Branding(brand: brand, showSpinner: true),
            data: (_) => _Branding(brand: brand, showSpinner: true),
            error: (_, __) => Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: ErrorView(
                message: 'We could not start the app. Check your connection.',
                onRetry: () => ref.invalidate(splashRedirectProvider),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Branding extends StatelessWidget {
  const _Branding({required this.brand, required this.showSpinner});

  final String brand;
  final bool showSpinner;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            borderRadius: BorderRadius.circular(AppRadius.xl),
          ),
          child: Icon(
            Icons.local_taxi_rounded,
            size: 48,
            color: theme.colorScheme.onPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Text(brand, style: theme.textTheme.headlineLarge),
        if (showSpinner) ...[
          const SizedBox(height: AppSpacing.xxl),
          const SizedBox(
            height: 28,
            width: 28,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ],
      ],
    );
  }
}
