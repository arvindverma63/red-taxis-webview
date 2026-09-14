import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/branded_logo.dart';
import '../../auth/application/auth_notifier.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutBack),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: const Interval(0.0, 0.7, curve: Curves.easeIn)),
    );

    _animController.forward();
    _navigateToNext();
  }

  void _navigateToNext() {
    Timer(const Duration(milliseconds: 1800), () {
      if (!mounted) return;
      final auth = ref.read(authProvider);
      if (auth.isAuthenticated) {
        context.go('/home');
      } else {
        context.go('/auth/login');
      }
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final branding = ref.watch(tenantBrandingProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Subtle radiant aura circles
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: branding.primaryColor.withOpacity(0.06),
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            left: -80,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: branding.primaryColor.withOpacity(0.04),
              ),
            ),
          ),

          // Central Logo and Title
          Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Glowing logo badge
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: branding.primaryColor.withOpacity(0.25),
                            blurRadius: 36,
                            spreadRadius: 6,
                          ),
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: BrandedLogo(branding: branding, size: 76, isDark: false),
                    ),
                    const SizedBox(height: 24),

                    // Fleet Name
                    Text(
                      branding.name,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Tagline
                    const Text(
                      'Fast, Reliable Rides at Your Fingertips',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                        letterSpacing: 0.1,
                      ),
                    ),
                    const SizedBox(height: 36),

                    // Clean spinner
                    SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        valueColor: AlwaysStoppedAnimation<Color>(branding.primaryColor),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Footer
          const Positioned(
            bottom: 24,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                'Passenger App • v1.0.0',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF94A3B8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
