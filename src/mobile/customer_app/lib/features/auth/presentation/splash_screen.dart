import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/widgets.dart';
import '../application/auth_controller.dart';

/// Professional animated splash screen for First Taxis.
///
/// Features hardware-accelerated telemetry radar sweeps, spring-scale logo
/// entrance with radiant breathing aura rings, staggered typography reveal,
/// and an animated road energy progress track before navigating to the resolved
/// destination.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entranceController;
  late final AnimationController _loopController;

  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;
  late final Animation<double> _titleFade;
  late final Animation<Offset> _titleSlide;
  late final Animation<double> _taglineFade;
  late final Animation<double> _progressFade;

  Timer? _minDurationTimer;
  String? _targetDestination;
  bool _navigated = false;
  bool _minDurationPassed = false;

  @override
  void initState() {
    super.initState();

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _loopController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();

    _logoScale = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.0, 0.65, curve: Curves.easeOutBack),
    );

    _logoFade = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.0, 0.45, curve: Curves.easeIn),
    );

    _titleFade = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.35, 0.75, curve: Curves.easeOut),
    );

    _titleSlide = Tween<Offset>(
      begin: const Offset(0, 0.35),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.35, 0.75, curve: Curves.easeOutCubic),
    ));

    _taglineFade = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.55, 0.85, curve: Curves.easeOut),
    );

    _progressFade = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.70, 1.0, curve: Curves.easeOut),
    );

    _entranceController.forward();

    // Ensure the animation is presented gracefully for at least ~1.8s
    _minDurationTimer = Timer(const Duration(milliseconds: 1800), () {
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
    _entranceController.dispose();
    _loopController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brand = AppConfig.fromEnvironment().brandName;
    final isDark = theme.brightness == Brightness.dark;

    // Listen to session restore destination
    ref.listen<AsyncValue<String>>(splashRedirectProvider, (_, next) {
      next.whenData((dest) {
        _targetDestination = dest;
        _checkAndNavigate();
      });
    });

    final redirect = ref.watch(splashRedirectProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background radar telemetry canvas
          AnimatedBuilder(
            animation: _loopController,
            builder: (context, _) {
              return CustomPaint(
                painter: _RadarTelemetryPainter(
                  progress: _loopController.value,
                  accentColor: AppColors.brand,
                  isDark: isDark,
                ),
              );
            },
          ),

          // Central Animated Brand Content
          SafeArea(
            child: Center(
              child: redirect.when(
                loading: () => _buildAnimatedContent(brand, isDark, theme),
                data: (_) => _buildAnimatedContent(brand, isDark, theme),
                error: (_, __) => Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: ErrorView(
                    message:
                        'We could not start $brand. Check your network connection.',
                    onRetry: () {
                      _minDurationPassed = true;
                      ref.invalidate(splashRedirectProvider);
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedContent(String brand, bool isDark, ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Pulsing Logo Container
        AnimatedBuilder(
          animation: _loopController,
          builder: (context, child) {
            final pulse = _loopController.value;
            return Stack(
              alignment: Alignment.center,
              children: [
                // Outer radiant aura ring 2
                Container(
                  width: 146 + (pulse * 28),
                  height: 146 + (pulse * 28),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.brand.withValues(
                      alpha: (1.0 - pulse) * 0.10,
                    ),
                  ),
                ),
                // Inner radiant aura ring 1
                Container(
                  width: 120 + (pulse * 18),
                  height: 120 + (pulse * 18),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFF7B500).withValues(
                      alpha: (1.0 - pulse) * 0.16,
                    ),
                  ),
                ),
                // Central Logo
                ScaleTransition(
                  scale: _logoScale,
                  child: FadeTransition(
                    opacity: _logoFade,
                    child: const BrandLogo(
                      size: 104,
                      showShadow: true,
                      showBorder: true,
                      borderRadius: BorderRadius.all(Radius.circular(28)),
                      padding: EdgeInsets.all(AppSpacing.md),
                    ),
                  ),
                ),
              ],
            );
          },
        ),

        const SizedBox(height: AppSpacing.xl),

        // Brand Title & Tagline
        SlideTransition(
          position: _titleSlide,
          child: FadeTransition(
            opacity: _titleFade,
            child: Column(
              children: [
                Text(
                  brand,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                FadeTransition(
                  opacity: _taglineFade,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 5,
                        height: 5,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFFF7B500),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        'PREMIUM RIDE DISPATCH',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2.4,
                          color: isDark
                              ? AppColors.neutral400
                              : AppColors.neutral600,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Container(
                        width: 5,
                        height: 5,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFFF7B500),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: AppSpacing.xxl),

        // Road Energy Track & Dispatch Status
        FadeTransition(
          opacity: _progressFade,
          child: Column(
            children: [
              AnimatedBuilder(
                animation: _loopController,
                builder: (context, _) {
                  return _RoadEnergyBar(
                    loopProgress: _loopController.value,
                    brandColor: AppColors.brand,
                    isDark: isDark,
                  );
                },
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Connecting to live fleet dispatch...',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isDark ? AppColors.neutral400 : AppColors.neutral500,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Draws subtle concentric telemetry orbits and radar ticks behind the logo.
class _RadarTelemetryPainter extends CustomPainter {
  _RadarTelemetryPainter({
    required this.progress,
    required this.accentColor,
    required this.isDark,
  });

  final double progress;
  final Color accentColor;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.44);
    final maxRadius = math.min(size.width, size.height) * 0.46;

    final ringPaint = Paint()
      ..color = accentColor.withValues(alpha: isDark ? 0.06 : 0.035)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Concentric orbit rings
    for (int i = 1; i <= 3; i++) {
      final r = maxRadius * (i / 3.0);
      canvas.drawCircle(center, r, ringPaint);
    }

    // Rotating telemetry tick indicators
    final angle = progress * 2 * math.pi;
    const tickLength = 10.0;
    for (int i = 0; i < 4; i++) {
      final a = angle + (i * math.pi / 2);
      final p1 = Offset(
        center.dx + (maxRadius - tickLength) * math.cos(a),
        center.dy + (maxRadius - tickLength) * math.sin(a),
      );
      final p2 = Offset(
        center.dx + maxRadius * math.cos(a),
        center.dy + maxRadius * math.sin(a),
      );
      canvas.drawLine(
        p1,
        p2,
        Paint()
          ..color = accentColor.withValues(alpha: isDark ? 0.18 : 0.10)
          ..strokeWidth = 1.5,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RadarTelemetryPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// A modern neon energy bar with an animated moving glow segment.
class _RoadEnergyBar extends StatelessWidget {
  const _RoadEnergyBar({
    required this.loopProgress,
    required this.brandColor,
    required this.isDark,
  });

  final double loopProgress;
  final Color brandColor;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    const trackWidth = 160.0;
    const glowWidth = 48.0;

    return Container(
      width: trackWidth,
      height: 4,
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : Colors.black12,
        borderRadius: BorderRadius.circular(2),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: (trackWidth - glowWidth) * loopProgress,
            child: Container(
              width: glowWidth,
              height: 4,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                gradient: LinearGradient(
                  colors: [
                    brandColor.withValues(alpha: 0.1),
                    brandColor,
                    const Color(0xFFF7B500),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: brandColor.withValues(alpha: 0.5),
                    blurRadius: 6,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
