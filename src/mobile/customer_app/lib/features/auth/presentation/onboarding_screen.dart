import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/widgets.dart';
import '../data/auth_repository.dart';

/// Two swipeable value-prop pages with a "Get started" CTA → Sign up and a
/// secondary "I already have an account" → Sign in. Marks onboarding as seen on
/// either choice so the splash skips it next launch.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  static const _pages = <_OnboardPage>[
    _OnboardPage(
      icon: Icons.local_taxi_rounded,
      title: 'Book a ride in seconds',
      body: 'Set your pickup and destination, see the fare up front, and '
          'request a taxi with a couple of taps.',
    ),
    _OnboardPage(
      icon: Icons.my_location_rounded,
      title: 'Track your driver live',
      body: 'Watch your driver approach on the map, get status updates, and '
          'review every trip in your history.',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _proceed(String location) async {
    await ref.read(authRepositoryProvider).markOnboardingSeen();
    if (!mounted) return;
    context.go(location);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLast = _page == _pages.length - 1;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => _proceed(Routes.signIn),
                  child: const Text('Skip'),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _pages.length,
                  onPageChanged: (i) => setState(() => _page = i),
                  itemBuilder: (_, i) => _pages[i],
                ),
              ),
              _Dots(count: _pages.length, active: _page),
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                label: isLast ? 'Get started' : 'Next',
                onPressed: () {
                  if (isLast) {
                    _proceed(Routes.signUp);
                  } else {
                    _controller.nextPage(
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOut,
                    );
                  }
                },
              ),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: 'I already have an account',
                variant: AppButtonVariant.text,
                onPressed: () => _proceed(Routes.signIn),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardPage extends StatelessWidget {
  const _OnboardPage({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AdaptiveCenter(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 64, color: theme.colorScheme.primary),
          ),
          const SizedBox(height: AppSpacing.xxl),
          Text(
            title,
            style: theme.textTheme.headlineLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            body,
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.active});

  final int count;
  final int active;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final selected = i == active;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          width: selected ? 22 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: selected
                ? theme.colorScheme.primary
                : theme.colorScheme.outline,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
        );
      }),
    );
  }
}
