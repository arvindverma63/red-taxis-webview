import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/widgets.dart';
import '../application/auth_controller.dart';

/// First screen: the First Taxis wordmark over a dotted yellow spinner while
/// [splashRedirectProvider] restores the session. Holds for a short minimum so
/// the brand is seen, then goes to Home, Onboarding or Sign in.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  Timer? _minDurationTimer;
  String? _targetDestination;
  bool _navigated = false;
  bool _minDurationPassed = false;

  @override
  void initState() {
    super.initState();
    _minDurationTimer = Timer(const Duration(milliseconds: 1400), () {
      if (!mounted) return;
      _minDurationPassed = true;
      _checkAndNavigate();
    });
  }

  void _checkAndNavigate() {
    if (_navigated || !mounted) return;
    if (_minDurationPassed && _targetDestination != null) {
      _navigated = true;
      context.go(_targetDestination!);
    }
  }

  @override
  void dispose() {
    _minDurationTimer?.cancel();
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brand = AppConfig.fromEnvironment().brandName;

    ref.listen<AsyncValue<String>>(splashRedirectProvider, (_, next) {
      next.whenData((dest) {
        _targetDestination = dest;
        _checkAndNavigate();
      });
    });

    final redirect = ref.watch(splashRedirectProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: redirect.hasError && !redirect.isLoading
            ? Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: ErrorView(
                  message:
                      'We could not start $brand. Check your network connection.',
                  onRetry: () {
                    _minDurationPassed = true;
                    ref.invalidate(splashRedirectProvider);
                  },
                ),
              )
            : SizedBox.expand(
                child: Column(
                  children: [
                    const Spacer(flex: 5),
                    const BrandWordmark(height: 52),
                    const Spacer(flex: 4),
                    RotationTransition(
                      turns: _spin,
                      child: const CustomPaint(
                        size: Size(44, 44),
                        painter: _DotSpinnerPainter(),
                      ),
                    ),
                    const Spacer(flex: 3),
                  ],
                ),
              ),
      ),
    );
  }
}

/// A ring of dots fading from solid yellow to pale, rotated by the parent.
class _DotSpinnerPainter extends CustomPainter {
  const _DotSpinnerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const dots = 10;
    final center = size.center(Offset.zero);
    final ring = size.width / 2 - 4;
    for (var i = 0; i < dots; i++) {
      final angle = 2 * 3.141592653589793 * i / dots;
      final t = i / dots;
      final paint = Paint()
        ..color = AppColors.brand.withValues(alpha: 0.15 + 0.85 * t);
      canvas.drawCircle(
        center + Offset.fromDirection(angle, ring),
        2 + 2 * t,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
