import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/widgets.dart';
import '../application/user_guide_controller.dart';

/// Shows the interactive 4-step First Taxis User Guide modal bottom sheet.
Future<void> showFirstTimeUserGuide(
  BuildContext context, {
  bool markAsSeen = true,
  VoidCallback? onGetStarted,
}) async {
  if (markAsSeen) {
    try {
      final container = ProviderScope.containerOf(context, listen: false);
      container.read(userGuideSeenProvider.notifier).markSeen();
    } catch (_) {}
  }

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _UserGuideSheet(onGetStarted: onGetStarted),
  );
}

class _UserGuideSheet extends StatefulWidget {
  const _UserGuideSheet({this.onGetStarted});

  final VoidCallback? onGetStarted;

  @override
  State<_UserGuideSheet> createState() => _UserGuideSheetState();
}

class _UserGuideSheetState extends State<_UserGuideSheet> {
  final _controller = PageController();
  int _page = 0;

  static const _steps = <_GuideStepData>[
    _GuideStepData(
      stepNumber: 1,
      badgeColor: Color(0xFF12B76A), // Emerald
      icon: Icons.explore_rounded,
      title: 'Set Your Journey',
      subtitle: 'Where would you like to go?',
      description:
          'Enter your destination in the "Where to?" card, select from your saved addresses, or tap "Pick on Map" to drop an exact pin anywhere across the region.',
      tips: [
        _GuideTip(
          icon: Icons.my_location_rounded,
          text: 'Your current GPS location is set as default pickup',
        ),
        _GuideTip(
          icon: Icons.bookmark_added_rounded,
          text: 'Save Home & Work for instantaneous 1-tap booking',
        ),
      ],
    ),
    _GuideStepData(
      stepNumber: 2,
      badgeColor: Color(0xFFFE2020), // Brand Red
      icon: Icons.local_taxi_rounded,
      title: 'Choose Fleet Vehicle',
      subtitle: 'Transparent upfront fares',
      description:
          'Select the vehicle that fits your journey: Saloon (1-4 passengers), Estate (spacious luggage), Executive (luxury travel), or 6/8-Seater MPVs for larger groups.',
      tips: [
        _GuideTip(
          icon: Icons.price_check_rounded,
          text: 'Fixed & transparent quotes with zero surge pricing',
        ),
        _GuideTip(
          icon: Icons.luggage_rounded,
          text: 'Inspect passenger capacity & luggage limits before ordering',
        ),
      ],
    ),
    _GuideStepData(
      stepNumber: 3,
      badgeColor: Color(0xFF2E90FA), // Blue
      icon: Icons.radar_rounded,
      title: 'Live Driver Tracking',
      subtitle: 'Real-time telemetry & arrival ETA',
      description:
          'Once your ride is dispatched, watch your driver approach on the live vector map. View driver ratings, vehicle make, and UK license plate numbers.',
      tips: [
        _GuideTip(
          icon: Icons.phone_in_talk_rounded,
          text: '1-tap direct calling and SMS chat with your driver',
        ),
        _GuideTip(
          icon: Icons.timer_outlined,
          text: 'Live ETA countdown alerts you the moment driver arrives',
        ),
      ],
    ),
    _GuideStepData(
      stepNumber: 4,
      badgeColor: Color(0xFF9E77ED), // Purple
      icon: Icons.receipt_long_rounded,
      title: 'Settlement & Receipts',
      subtitle: 'Safe payments & official records',
      description:
          'Pay seamlessly using Cash or in-app payment. When your journey is completed, an official itemized First Taxis digital receipt is automatically generated and archived.',
      tips: [
        _GuideTip(
          icon: Icons.copy_rounded,
          text: 'View, copy, and share itemized fare breakdown receipts',
        ),
        _GuideTip(
          icon: Icons.shield_rounded,
          text: '24/7 dedicated dispatch hotline available on every trip',
        ),
      ],
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_page < _steps.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    } else {
      Navigator.of(context).pop();
      widget.onGetStarted?.call();
    }
  }

  void _back() {
    if (_page > 0) {
      _controller.previousPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isLast = _page == _steps.length - 1;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.xl),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.15),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          const SizedBox(height: AppSpacing.sm),
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? AppColors.neutral700 : AppColors.neutral300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header Row
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.xs,
            ),
            child: Row(
              children: [
                const BrandLogo(size: 28, showBorder: true),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'First Taxis User Guide',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.brand.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    'Step ${_page + 1} of ${_steps.length}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.brand,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  tooltip: 'Close guide',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Page Carousel
          SizedBox(
            height: 390,
            child: PageView.builder(
              controller: _controller,
              itemCount: _steps.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (context, index) {
                return _GuideStepPage(data: _steps[index]);
              },
            ),
          ),

          // Bottom Controls
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: Column(
              children: [
                // Dots Indicator
                _GuideDots(count: _steps.length, active: _page),
                const SizedBox(height: AppSpacing.lg),

                // Action Buttons
                Row(
                  children: [
                    if (_page > 0) ...[
                      Expanded(
                        flex: 1,
                        child: AppButton(
                          label: 'Back',
                          variant: AppButtonVariant.secondary,
                          onPressed: _back,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                    ],
                    Expanded(
                      flex: 2,
                      child: AppButton(
                        label: isLast ? 'Ready to Ride! 🚀' : 'Next Step ➔',
                        onPressed: _next,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GuideStepData {
  const _GuideStepData({
    required this.stepNumber,
    required this.badgeColor,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.tips,
  });

  final int stepNumber;
  final Color badgeColor;
  final IconData icon;
  final String title;
  final String subtitle;
  final String description;
  final List<_GuideTip> tips;
}

class _GuideTip {
  const _GuideTip({required this.icon, required this.text});
  final IconData icon;
  final String text;
}

class _GuideStepPage extends StatelessWidget {
  const _GuideStepPage({required this.data});

  final _GuideStepData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.md,
      ),
      child: Column(
        children: [
          // Graphic Emblem
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: data.badgeColor.withValues(alpha: isDark ? 0.22 : 0.12),
                ),
              ),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: data.badgeColor,
                  boxShadow: [
                    BoxShadow(
                      color: data.badgeColor.withValues(alpha: 0.45),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  data.icon,
                  size: 38,
                  color: Colors.white,
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.md),

          // Titles
          Text(
            data.title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            data.subtitle,
            style: theme.textTheme.labelMedium?.copyWith(
              color: AppColors.brand,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: AppSpacing.sm),

          // Body Description
          Text(
            data.description,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isDark ? AppColors.neutral300 : AppColors.neutral600,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: AppSpacing.md),

          // Feature Tips Cards
          ...data.tips.map(
            (tip) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs + 2,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.neutral800
                      : AppColors.neutral50,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: isDark ? AppColors.neutral700 : AppColors.neutral200,
                    width: 0.8,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      tip.icon,
                      size: 18,
                      color: data.badgeColor,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        tip.text,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GuideDots extends StatelessWidget {
  const _GuideDots({required this.count, required this.active});

  final int count;
  final int active;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final selected = i == active;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: selected ? 24 : 8,
          height: 6,
          decoration: BoxDecoration(
            color: selected ? AppColors.brand : AppColors.neutral300,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
        );
      }),
    );
  }
}
