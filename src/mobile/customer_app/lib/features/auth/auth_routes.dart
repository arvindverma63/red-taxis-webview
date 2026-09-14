import 'package:go_router/go_router.dart';

import '../../core/router/route_paths.dart';
import 'presentation/forgot_password_screen.dart';
import 'presentation/onboarding_screen.dart';
import 'presentation/reset_password_screen.dart';
import 'presentation/sign_in_screen.dart';
import 'presentation/sign_up_screen.dart';
import 'presentation/splash_screen.dart';
import 'presentation/verify_email_screen.dart';

/// Top-level auth + onboarding routes. The app router spreads these alongside
/// the shell/tab routes. Deep-linkable screens (`reset-password`,
/// `verify-email`) read their `email` / `token` from the query string — these
/// are the targets of the links emailed by the backend.
final List<RouteBase> authRoutes = [
  GoRoute(
    path: Routes.splash,
    name: 'splash',
    builder: (context, state) => const SplashScreen(),
  ),
  GoRoute(
    path: Routes.onboarding,
    name: 'onboarding',
    builder: (context, state) => const OnboardingScreen(),
  ),
  GoRoute(
    path: Routes.signIn,
    name: 'signIn',
    builder: (context, state) => const SignInScreen(),
  ),
  GoRoute(
    path: Routes.signUp,
    name: 'signUp',
    builder: (context, state) => const SignUpScreen(),
  ),
  GoRoute(
    path: Routes.forgotPassword,
    name: 'forgotPassword',
    builder: (context, state) => const ForgotPasswordScreen(),
  ),
  GoRoute(
    path: Routes.resetPassword,
    name: 'resetPassword',
    builder: (context, state) => ResetPasswordScreen(
      email: state.uri.queryParameters['email'] ?? '',
      token: state.uri.queryParameters['token'] ?? '',
    ),
  ),
  GoRoute(
    path: Routes.verifyEmail,
    name: 'verifyEmail',
    builder: (context, state) => VerifyEmailScreen(
      email: state.uri.queryParameters['email'] ?? '',
      token: state.uri.queryParameters['token'],
    ),
  ),
];
