import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/widgets.dart';
import '../data/auth_repository.dart';

/// Three swipeable intro slides (brand, live tracking, payments) with a Skip
/// link and a Continue / Get Started button → Sign in. Marks onboarding as seen
/// so the splash skips it next launch.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  static const _pageCount = 3;

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
    final isLast = _page == _pageCount - 1;

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
                child: PageView(
                  controller: _controller,
                  onPageChanged: (i) => setState(() => _page = i),
                  children: const [
                    _OnboardPage(
                      title: 'Your Ride Starts Here',
                      body:
                          'Book a reliable taxi in just a few taps. Fast, '
                          'simple, and convenient.',
                      art: BrandWordmark(height: 54),
                    ),
                    _OnboardPage(
                      title: 'Track Your Ride',
                      body:
                          'Know where your driver is and follow your journey '
                          'in real time.',
                      art: _PhoneArt(child: _TrackingMock()),
                    ),
                    _OnboardPage(
                      title: 'Pay Your Way',
                      body:
                          'Pay securely by card or cash. Simple, flexible, '
                          'and hassle-free.',
                      art: _PhoneArt(child: _PaymentMock()),
                    ),
                  ],
                ),
              ),
              _Dots(count: _pageCount, active: _page),
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                label: isLast ? 'Get Started' : 'Continue',
                onPressed: () {
                  if (isLast) {
                    _proceed(Routes.signIn);
                  } else {
                    _controller.nextPage(
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOut,
                    );
                  }
                },
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
    required this.title,
    required this.body,
    required this.art,
  });

  final String title;
  final String body;
  final Widget art;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Expanded(flex: 5, child: Center(child: art)),
        Text(
          title,
          style: theme.textTheme.headlineLarge?.copyWith(
            fontWeight: FontWeight.w400,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.md),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Text(
            body,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: AppColors.neutral500,
              fontWeight: FontWeight.w400,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const Spacer(flex: 2),
      ],
    );
  }
}

/// Pale yellow disc with a simplified phone showing [child].
class _PhoneArt extends StatelessWidget {
  const _PhoneArt({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 250,
      height: 290,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 220,
            height: 220,
            decoration: const BoxDecoration(
              color: Color(0xFFFFE9A6),
              shape: BoxShape.circle,
            ),
          ),
          Container(
            width: 132,
            height: 250,
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(22),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 14,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: ColoredBox(color: const Color(0xFFF3F3F3), child: child),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniHeader extends StatelessWidget {
  const _MiniHeader();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.fromLTRB(8, 12, 8, 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [BrandWordmark(height: 16)],
        ),
      );
}

class _TrackingMock extends StatelessWidget {
  const _TrackingMock();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _MiniHeader(),
        Expanded(
          child: CustomPaint(
            painter: _MiniMapPainter(),
            child: const SizedBox.expand(),
          ),
        ),
        Container(
          margin: const EdgeInsets.all(6),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(
            children: [
              CircleAvatar(radius: 9, backgroundColor: AppColors.brand),
              SizedBox(width: 5),
              Expanded(
                child: Text(
                  'Mark D.  ·  3 min',
                  style: TextStyle(fontSize: 7, fontWeight: FontWeight.w700),
                ),
              ),
              Icon(Icons.phone, size: 10),
            ],
          ),
        ),
      ],
    );
  }
}

class _MiniMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final road = Paint()
      ..color = Colors.white
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke;
    canvas
      ..drawLine(Offset(0, size.height * .3), Offset(size.width, size.height * .45), road)
      ..drawLine(Offset(size.width * .3, 0), Offset(size.width * .5, size.height), road);
    final route = Paint()
      ..color = AppColors.brand
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(size.width * .25, size.height * .85)
      ..lineTo(size.width * .25, size.height * .55)
      ..lineTo(size.width * .7, size.height * .45)
      ..lineTo(size.width * .7, size.height * .15);
    canvas.drawPath(path, route);
    canvas.drawCircle(
      Offset(size.width * .7, size.height * .12),
      5,
      Paint()..color = AppColors.brand,
    );
    canvas.drawCircle(
      Offset(size.width * .25, size.height * .85),
      4,
      Paint()..color = Colors.black,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PaymentMock extends StatelessWidget {
  const _PaymentMock();

  @override
  Widget build(BuildContext context) {
    Widget row(String name, {bool selected = false}) => Container(
          margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: selected ? AppColors.brand : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(fontSize: 7, fontWeight: FontWeight.w700),
                ),
              ),
              Icon(
                selected ? Icons.check_circle : Icons.circle_outlined,
                size: 10,
                color: selected ? AppColors.brand : Colors.black38,
              ),
            ],
          ),
        );

    return Column(
      children: [
        const _MiniHeader(),
        row('Credit / Debit Card', selected: true),
        row('Mastercard'),
        row('PayPal'),
        row('Google Pay'),
        row('Apple Pay'),
        row('Cash'),
        const Spacer(),
        Container(
          margin: const EdgeInsets.all(6),
          height: 18,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.brand,
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Text(
            'Pay Now',
            style: TextStyle(fontSize: 7, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.active});

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
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: selected ? AppColors.brand : AppColors.neutral200,
            shape: BoxShape.circle,
          ),
        );
      }),
    );
  }
}
