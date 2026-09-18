import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:driver_app/features/auth/auth.dart';
import 'package:driver_app/core/theme/theme.dart';
import 'package:driver_app/core/widgets/widgets.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _pulseController;
  late AnimationController _sweepController;

  late Animation<double> _logoScale;
  late Animation<double> _logoFade;
  late Animation<double> _textFade;
  late Animation<Offset> _textSlide;
  late Animation<double> _progressValue;

  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();

    // 1. Fast, snappy main entrance controller (750ms total)
    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );

    // Spring elastic / back pop-in for the central vector emblem
    _logoScale = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOutBack),
      ),
    );
    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
      ),
    );

    // Staggered text entrance
    _textFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.35, 0.85, curve: Curves.easeIn),
      ),
    );
    _textSlide = Tween<Offset>(
      begin: const Offset(0.0, 0.25),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.35, 0.9, curve: Curves.easeOutCubic),
      ),
    );

    // Fast vector progress bar filling smoothly
    _progressValue = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    // 2. Vector Pulse & Orbit Controllers for ambient live feel
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _sweepController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();

    // Start entrance animation
    _mainController.forward();

    // Navigate immediately when entrance animation finishes (or upon auth resolution)
    _mainController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _checkAuthAndNavigate();
      }
    });
  }

  @override
  void dispose() {
    _mainController.dispose();
    _pulseController.dispose();
    _sweepController.dispose();
    super.dispose();
  }

  void _checkAuthAndNavigate() {
    if (_hasNavigated || !mounted) return;
    final authState = ref.read(authProvider);
    if (authState.status != AuthStatus.authenticating) {
      _navigateToNextScreen(authState.status);
    }
  }

  void _navigateToNextScreen(AuthStatus status) {
    if (_hasNavigated || !mounted) return;
    _hasNavigated = true;
    if (status == AuthStatus.authenticated) {
      context.go('/');
    } else {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen to auth state transitions
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (_mainController.isCompleted && next.status != AuthStatus.authenticating) {
        _checkAuthAndNavigate();
      }
    });

    final authState = ref.watch(authProvider);
    final branding = authState.tenantBranding ?? TenantBranding.defaultFirstTaxis();
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    final primaryColor = branding.primaryColor;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : const Color(0xFFF8F9FA),
      body: Stack(
        children: [
          // 1. Vector Ambient Background Grid & Radial Glow
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return CustomPaint(
                  painter: _VectorBackgroundPainter(
                    primaryColor: primaryColor,
                    pulseValue: _pulseController.value,
                    isDark: isDark,
                  ),
                );
              },
            ),
          ),

          // 2. Main Centered Visual Content
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(flex: 3),

                    // Central Vector Radar Orbit & Animated Logo Badge
                    SizedBox(
                      width: 200,
                      height: 200,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Vector Radar Sweeps & Concentric Tech Rings
                          AnimatedBuilder(
                            animation: Listenable.merge([_pulseController, _sweepController]),
                            builder: (context, child) {
                              return CustomPaint(
                                size: const Size(200, 200),
                                painter: _VectorRadarRingPainter(
                                  primaryColor: primaryColor,
                                  sweepAngle: _sweepController.value * 2 * math.pi,
                                  pulseScale: 0.9 + (_pulseController.value * 0.12),
                                  isDark: isDark,
                                ),
                              );
                            },
                          ),

                          // Floating Branded Logo Card
                          ScaleTransition(
                            scale: _logoScale,
                            child: FadeTransition(
                              opacity: _logoFade,
                              child: Container(
                                width: 130,
                                height: 130,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isDark ? const Color(0xFF1E1E24) : Colors.white,
                                  boxShadow: [
                                    BoxShadow(
                                      color: primaryColor.withValues(alpha: isDark ? 0.35 : 0.22),
                                      blurRadius: 28,
                                      spreadRadius: 2,
                                      offset: const Offset(0, 8),
                                    ),
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.06),
                                      blurRadius: 14,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                  border: Border.all(
                                    color: primaryColor.withValues(alpha: 0.18),
                                    width: 2.5,
                                  ),
                                ),
                                padding: const EdgeInsets.all(16),
                                child: ClipOval(
                                  child: BrandedLogo(
                                    branding: branding,
                                    size: 90,
                                    fit: BoxFit.contain,
                                    fallbackIcon: Icons.local_taxi_rounded,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Animated Brand Title & Tagline
                    SlideTransition(
                      position: _textSlide,
                      child: FadeTransition(
                        opacity: _textFade,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              branding.name.toUpperCase(),
                              style: TextStyle(
                                color: isDark ? Colors.white : primaryColor,
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.8,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: primaryColor.withValues(alpha: isDark ? 0.15 : 0.08),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: primaryColor.withValues(alpha: 0.2),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: primaryColor,
                                      boxShadow: [
                                        BoxShadow(
                                          color: primaryColor.withValues(alpha: 0.8),
                                          blurRadius: 4,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'PROFESSIONAL DRIVER DISPATCH',
                                    style: TextStyle(
                                      color: isDark ? const Color(0xFFB0BEC5) : AppTheme.textLightSecondary,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const Spacer(flex: 2),

                    // Vector Fast Progress Beacon Track
                    AnimatedBuilder(
                      animation: _progressValue,
                      builder: (context, child) {
                        return _buildVectorProgressTrack(
                          progress: _progressValue.value,
                          primaryColor: primaryColor,
                          isDark: isDark,
                        );
                      },
                    ),

                    const SizedBox(height: 36),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVectorProgressTrack({
    required double progress,
    required Color primaryColor,
    required bool isDark,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 180,
          height: 6,
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              // Background track
              Container(
                width: 180,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2D2D35) : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              // Active glowing vector progress bar
              FractionallySizedBox(
                widthFactor: progress.clamp(0.02, 1.0),
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        primaryColor.withValues(alpha: 0.3),
                        primaryColor,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withValues(alpha: 0.6),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lock_outline_rounded,
              size: 12,
              color: isDark ? const Color(0xFF78909C) : const Color(0xFF90A4AE),
            ),
            const SizedBox(width: 4),
            Text(
              'Secure Telemetry Active',
              style: TextStyle(
                color: isDark ? const Color(0xFF78909C) : const Color(0xFF90A4AE),
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Custom Vector Painter for ambient radar sweep, dashed telemetry orbits & ticks
class _VectorRadarRingPainter extends CustomPainter {
  final Color primaryColor;
  final double sweepAngle;
  final double pulseScale;
  final bool isDark;

  _VectorRadarRingPainter({
    required this.primaryColor,
    required this.sweepAngle,
    required this.pulseScale,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = (size.width / 2) - 8;

    // 1. Outer Orbit Pulsing Ring
    final pulsePaint = Paint()
      ..color = primaryColor.withValues(alpha: isDark ? 0.12 : 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawCircle(center, baseRadius * pulseScale, pulsePaint);

    // 2. Outer Dashed Ring
    final dashedPaint = Paint()
      ..color = primaryColor.withValues(alpha: isDark ? 0.25 : 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    const int dashCount = 28;
    final double dashAngle = (2 * math.pi) / dashCount;
    for (int i = 0; i < dashCount; i++) {
      if (i % 2 == 0) {
        final startAngle = i * dashAngle;
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: baseRadius),
          startAngle,
          dashAngle * 0.6,
          false,
          dashedPaint,
        );
      }
    }

    // 3. Four Cardinal Vector Orbit Notches / Crosshairs
    final notchPaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < 4; i++) {
      final angle = (i * math.pi / 2);
      final p1 = Offset(
        center.dx + (baseRadius - 5) * math.cos(angle),
        center.dy + (baseRadius - 5) * math.sin(angle),
      );
      final p2 = Offset(
        center.dx + (baseRadius + 5) * math.cos(angle),
        center.dy + (baseRadius + 5) * math.sin(angle),
      );
      canvas.drawLine(p1, p2, notchPaint);
    }

    // 4. Rotating Vector Laser Sweep Arc
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        startAngle: 0.0,
        endAngle: math.pi * 0.7,
        colors: [
          Colors.transparent,
          primaryColor.withValues(alpha: 0.0),
          primaryColor.withValues(alpha: isDark ? 0.45 : 0.35),
        ],
        transform: GradientRotation(sweepAngle),
      ).createShader(Rect.fromCircle(center: center, radius: baseRadius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: baseRadius),
      sweepAngle,
      math.pi * 0.7,
      false,
      sweepPaint,
    );

    // Leading glowing vector beacon dot
    final beaconCenter = Offset(
      center.dx + baseRadius * math.cos(sweepAngle + math.pi * 0.7),
      center.dy + baseRadius * math.sin(sweepAngle + math.pi * 0.7),
    );

    final glowPaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(beaconCenter, 5, glowPaint);

    final dotPaint = Paint()..color = isDark ? Colors.white : primaryColor;
    canvas.drawCircle(beaconCenter, 2.5, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _VectorRadarRingPainter oldDelegate) {
    return oldDelegate.sweepAngle != sweepAngle ||
        oldDelegate.pulseScale != pulseScale ||
        oldDelegate.primaryColor != primaryColor ||
        oldDelegate.isDark != isDark;
  }
}

/// Custom Background Vector Painter for soft radial glow & ambient geometry
class _VectorBackgroundPainter extends CustomPainter {
  final Color primaryColor;
  final double pulseValue;
  final bool isDark;

  _VectorBackgroundPainter({
    required this.primaryColor,
    required this.pulseValue,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.42);

    // Soft Radial Aura Glow
    final glowRadius = size.width * (0.65 + (pulseValue * 0.08));
    final auraPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          primaryColor.withValues(alpha: isDark ? 0.09 : 0.06),
          primaryColor.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: glowRadius));

    canvas.drawCircle(center, glowRadius, auraPaint);
  }

  @override
  bool shouldRepaint(covariant _VectorBackgroundPainter oldDelegate) {
    return oldDelegate.pulseValue != pulseValue ||
        oldDelegate.primaryColor != primaryColor ||
        oldDelegate.isDark != isDark;
  }
}
