import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/booking_status.dart';

/// Vertical progress timeline of the booking lifecycle, matching the expanded
/// GoRide tracking detail (frame `30439:404`). Completed steps fill with the
/// brand accent and a check; the current step pulses; future steps are muted.
/// Data is driven entirely by [BookingStatusX.timelineOrder] + [current].
class StatusTimeline extends StatelessWidget {
  const StatusTimeline({super.key, required this.current});

  final BookingStatus current;

  @override
  Widget build(BuildContext context) {
    final steps = BookingStatusX.timelineOrder;
    final currentIndex = current.timelineIndex;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < steps.length; i++)
          _TimelineRow(
            status: steps[i],
            isFirst: i == 0,
            isLast: i == steps.length - 1,
            isDone: currentIndex >= 0 && i < currentIndex,
            isCurrent: i == currentIndex,
          ),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.status,
    required this.isFirst,
    required this.isLast,
    required this.isDone,
    required this.isCurrent,
  });

  final BookingStatus status;
  final bool isFirst;
  final bool isLast;
  final bool isDone;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reached = isDone || isCurrent;
    final accent = AppColors.brand;
    final muted = theme.colorScheme.outline;
    final dotColor = reached ? accent : theme.colorScheme.surface;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 24,
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    width: AppStroke.thin + 1,
                    color: isFirst
                        ? Colors.transparent
                        : (isDone ? accent : muted),
                  ),
                ),
                _Dot(
                  color: dotColor,
                  borderColor: reached ? accent : muted,
                  filled: reached,
                  pulsing: isCurrent,
                ),
                Expanded(
                  child: Container(
                    width: AppStroke.thin + 1,
                    color: isLast
                        ? Colors.transparent
                        : (isDone ? accent : muted),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Text(
              status.timelineLabel,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: reached
                    ? theme.colorScheme.onSurface
                    : theme.textTheme.bodySmall?.color,
                fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({
    required this.color,
    required this.borderColor,
    required this.filled,
    required this.pulsing,
  });

  final Color color;
  final Color borderColor;
  final bool filled;
  final bool pulsing;

  @override
  Widget build(BuildContext context) {
    final dot = Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 2),
      ),
      child: filled
          ? const Icon(Icons.check, size: 10, color: AppColors.onBrand)
          : null,
    );
    if (!pulsing) return dot;
    return _PulseRing(child: dot);
  }
}

/// A soft pulsing halo around the current-step dot.
class _PulseRing extends StatefulWidget {
  const _PulseRing({required this.child});

  final Widget child;

  @override
  State<_PulseRing> createState() => _PulseRingState();
}

class _PulseRingState extends State<_PulseRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        return SizedBox(
          width: 28,
          height: 28,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 16 + 12 * t,
                height: 16 + 12 * t,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.brand.withValues(alpha: 0.25 * (1 - t)),
                ),
              ),
              child!,
            ],
          ),
        );
      },
      child: widget.child,
    );
  }
}
