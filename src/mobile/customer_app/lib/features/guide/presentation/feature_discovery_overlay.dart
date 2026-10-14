import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

/// Represents a single feature to highlight in the Google-style discovery tour.
class FeatureDiscoveryStep {
  const FeatureDiscoveryStep({
    required this.targetKey,
    required this.title,
    required this.description,
    required this.icon,
    this.borderRadius = 16.0,
    this.accentColor = const Color(0xFFFE2020),
    this.tag = 'FEATURE TOUR',
  });

  /// The GlobalKey assigned to the widget to spotlight.
  final GlobalKey targetKey;

  /// Headline title for this feature.
  final String title;

  /// Detailed description explaining the feature.
  final String description;

  /// Icon badge representing this step.
  final IconData icon;

  /// Corner radius for the cutout spotlight around the target widget.
  final double borderRadius;

  /// Accent color for the glowing aura and badges.
  final Color accentColor;

  /// Category tag text shown above the title.
  final String tag;
}

/// Launches the Google-style feature highlight discovery tour over the active screen.
void showGoogleFeatureDiscovery({
  required BuildContext context,
  required List<FeatureDiscoveryStep> steps,
  VoidCallback? onComplete,
  VoidCallback? onDismiss,
}) {
  if (steps.isEmpty) return;

  final overlay = Overlay.of(context, rootOverlay: true);
  late final OverlayEntry entry;

  entry = OverlayEntry(
    builder: (ctx) => _FeatureDiscoveryWidget(
      steps: steps,
      onFinish: () {
        entry.remove();
        onComplete?.call();
      },
      onDismiss: () {
        entry.remove();
        onDismiss?.call();
      },
    ),
  );

  overlay.insert(entry);
}

class _FeatureDiscoveryWidget extends StatefulWidget {
  const _FeatureDiscoveryWidget({
    required this.steps,
    required this.onFinish,
    required this.onDismiss,
  });

  final List<FeatureDiscoveryStep> steps;
  final VoidCallback onFinish;
  final VoidCallback onDismiss;

  @override
  State<_FeatureDiscoveryWidget> createState() =>
      _FeatureDiscoveryWidgetState();
}

class _FeatureDiscoveryWidgetState extends State<_FeatureDiscoveryWidget>
    with TickerProviderStateMixin {
  int _currentIndex = 0;

  late final AnimationController _pulseController;
  late final AnimationController _rectController;
  late final AnimationController _cardFadeController;

  Rect? _currentRect;
  Rect? _targetRect;
  double _currentRadius = 16.0;
  double _targetRadius = 16.0;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();

    _rectController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );

    _cardFadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
      value: 1.0,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _resolveTargetRect(initial: true);
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rectController.dispose();
    _cardFadeController.dispose();
    super.dispose();
  }

  void _resolveTargetRect({bool initial = false}) {
    if (_currentIndex < 0 || _currentIndex >= widget.steps.length) return;

    final step = widget.steps[_currentIndex];
    final targetContext = step.targetKey.currentContext;

    if (targetContext != null) {
      // Scroll into view if needed
      Scrollable.ensureVisible(
        targetContext,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        alignment: 0.4,
      ).then((_) {
        if (!mounted) return;
        _measureAndAnimate(step, initial);
      });
    } else {
      _measureAndAnimate(step, initial);
    }
  }

  void _measureAndAnimate(FeatureDiscoveryStep step, bool initial) {
    final renderBox =
        step.targetKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) {
      if (initial) {
        setState(() {
          _currentRect = null;
        });
      }
      return;
    }

    final offset = renderBox.localToGlobal(Offset.zero);
    final newRect = Rect.fromLTWH(
      offset.dx,
      offset.dy,
      renderBox.size.width,
      renderBox.size.height,
    );

    if (initial) {
      setState(() {
        _currentRect = newRect;
        _targetRect = newRect;
        _currentRadius = step.borderRadius;
        _targetRadius = step.borderRadius;
      });
    } else {
      setState(() {
        _currentRect = _targetRect ?? newRect;
        _targetRect = newRect;
        _currentRadius = _targetRadius;
        _targetRadius = step.borderRadius;
      });
      _rectController.forward(from: 0.0);
      _cardFadeController.forward(from: 0.0);
    }
  }

  void _next() {
    if (_currentIndex < widget.steps.length - 1) {
      _cardFadeController.reverse().then((_) {
        if (!mounted) return;
        setState(() => _currentIndex++);
        _resolveTargetRect();
      });
    } else {
      widget.onFinish();
    }
  }

  void _back() {
    if (_currentIndex > 0) {
      _cardFadeController.reverse().then((_) {
        if (!mounted) return;
        setState(() => _currentIndex--);
        _resolveTargetRect();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final step = widget.steps[_currentIndex];
    final screenSize = MediaQuery.sizeOf(context);

    // Calculate interpolated spotlight rect
    Rect? animatedRect;
    double animatedRadius = _targetRadius;
    if (_currentRect != null && _targetRect != null) {
      final t = Curves.easeInOutCubic.transform(_rectController.value);
      animatedRect = Rect.lerp(_currentRect, _targetRect, t);
      animatedRadius =
          _currentRadius + ((_targetRadius - _currentRadius) * t);
    } else {
      animatedRect = _targetRect;
    }

    return Material(
      color: Colors.transparent,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Spotlight Scrim Canvas
          AnimatedBuilder(
            animation: Listenable.merge([_pulseController, _rectController]),
            builder: (context, _) {
              return CustomPaint(
                painter: _SpotlightOverlayPainter(
                  targetRect: animatedRect,
                  borderRadius: animatedRadius,
                  pulseValue: _pulseController.value,
                  accentColor: step.accentColor,
                  scrimColor: const Color(0xD9000000), // Rich 85% black veil
                ),
              );
            },
          ),

          // Tap outside to advance
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _next,
              child: const SizedBox.expand(),
            ),
          ),

          // Callout Details Card
          if (animatedRect != null)
            _buildCalloutCard(
              context: context,
              theme: theme,
              isDark: isDark,
              step: step,
              targetRect: animatedRect,
              screenSize: screenSize,
            ),
        ],
      ),
    );
  }

  Widget _buildCalloutCard({
    required BuildContext context,
    required ThemeData theme,
    required bool isDark,
    required FeatureDiscoveryStep step,
    required Rect targetRect,
    required Size screenSize,
  }) {
    final isTopHalf = targetRect.center.dy < (screenSize.height * 0.52);
    final cardWidth = math.min(screenSize.width - 36.0, 360.0);

    // Determine vertical placement
    double? top;
    double? bottom;

    if (isTopHalf) {
      top = math.min(
        targetRect.bottom + 22.0,
        screenSize.height - 240.0,
      );
    } else {
      bottom = math.min(
        (screenSize.height - targetRect.top) + 22.0,
        screenSize.height - 240.0,
      );
    }

    // Horizontal centering relative to screen
    final left = (screenSize.width - cardWidth) / 2;

    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      width: cardWidth,
      child: FadeTransition(
        opacity: _cardFadeController,
        child: GestureDetector(
          // Absorb taps on the card so it doesn't trigger tap-outside
          onTap: () {},
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: isDark ? AppColors.neutral800 : Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(
                color: step.accentColor.withValues(alpha: isDark ? 0.45 : 0.25),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: step.accentColor.withValues(alpha: 0.25),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Row (Pill Badge + Skip)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: step.accentColor.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            step.icon,
                            size: 13,
                            color: step.accentColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'STEP ${_currentIndex + 1} OF ${widget.steps.length}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: step.accentColor,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        foregroundColor: isDark
                            ? AppColors.neutral400
                            : AppColors.neutral500,
                      ),
                      onPressed: widget.onDismiss,
                      child: const Text('Skip tour'),
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.sm),

                // Title
                Text(
                  step.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),

                const SizedBox(height: AppSpacing.xs),

                // Description
                Text(
                  step.description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isDark ? AppColors.neutral300 : AppColors.neutral600,
                    height: 1.38,
                  ),
                ),

                const SizedBox(height: AppSpacing.lg),

                // Actions Row
                Row(
                  children: [
                    if (_currentIndex > 0) ...[
                      Expanded(
                        flex: 1,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 44),
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.sm,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                          ),
                          onPressed: _back,
                          child: const Text('Back'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                    ],
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(0, 44),
                          backgroundColor: step.accentColor,
                          foregroundColor: Colors.white,
                          elevation: 3,
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.sm + 2,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                        ),
                        onPressed: _next,
                        child: Text(
                          _currentIndex == widget.steps.length - 1
                              ? 'Got It, Let\'s Ride! 🚀'
                              : 'Next ➔',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// CustomPainter that renders the darkened scrim backdrop with a glowing cutout spotlight.
class _SpotlightOverlayPainter extends CustomPainter {
  _SpotlightOverlayPainter({
    required this.targetRect,
    required this.borderRadius,
    required this.pulseValue,
    required this.accentColor,
    required this.scrimColor,
  });

  final Rect? targetRect;
  final double borderRadius;
  final double pulseValue;
  final Color accentColor;
  final Color scrimColor;

  @override
  void paint(Canvas canvas, Size size) {
    final screenPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    if (targetRect == null) {
      canvas.drawPath(screenPath, Paint()..color = scrimColor);
      return;
    }

    // Expand the target rect slightly for breathing room
    final paddedRect = targetRect!.inflate(6.0);
    final cutoutRRect = RRect.fromRectAndRadius(
      paddedRect,
      Radius.circular(borderRadius),
    );

    // Punch out the spotlight hole through the dark scrim
    final cutoutPath = Path()..addRRect(cutoutRRect);
    final overlayPath = Path.combine(
      PathOperation.difference,
      screenPath,
      cutoutPath,
    );

    // Draw the dimmed background
    canvas.drawPath(overlayPath, Paint()..color = scrimColor);

    // Google-style expanding animated aura ring
    final auraPadding = 6.0 + (pulseValue * 14.0);
    final auraRRect = RRect.fromRectAndRadius(
      paddedRect.inflate(auraPadding),
      Radius.circular(borderRadius + (auraPadding * 0.7)),
    );

    final auraPaint = Paint()
      ..color = accentColor.withValues(alpha: (1.0 - pulseValue) * 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4;

    canvas.drawRRect(auraRRect, auraPaint);

    // Crisp inner target boundary stroke
    final borderPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawRRect(cutoutRRect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _SpotlightOverlayPainter oldDelegate) => true;
}
