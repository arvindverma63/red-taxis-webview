import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/router/route_paths.dart';
import '../data/auth_repository.dart';

/// Drives auth actions for the screens. Each method flips this notifier's
/// [AsyncValue] to loading, runs the repository call, and lands on data (success)
/// or error (message safe to show). Screens watch `authControllerProvider` for
/// the spinner + error text and read `.future`/return value for navigation.
class AuthController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {
    // Idle until an action runs.
  }

  AuthRepository get _repo => ref.read(authRepositoryProvider);

  /// Runs [action] inside a loading→data/error transition. Returns true on
  /// success so the caller can navigate; false when an error was captured.
  Future<bool> _run(Future<void> Function() action) async {
    state = const AsyncValue<void>.loading();
    try {
      await action();
      state = const AsyncValue<void>.data(null);
      return true;
    } on ApiException catch (e, st) {
      state = AsyncValue<void>.error(e, st);
      return false;
    } catch (e, st) {
      state = AsyncValue<void>.error(
        const ApiException('Something went wrong. Please try again.'),
        st,
      );
      return false;
    }
  }

  Future<bool> login({
    required String usernameOrEmail,
    required String password,
  }) =>
      _run(() => _repo.login(
            usernameOrEmail: usernameOrEmail,
            password: password,
          ));

  Future<bool> registerCustomer({
    required String fullName,
    required String email,
    required String phoneNumber,
    required String password,
  }) =>
      _run(() => _repo.registerCustomer(
            fullName: fullName,
            email: email,
            phoneNumber: phoneNumber,
            password: password,
          ));

  Future<bool> forgotPassword(String email) =>
      _run(() => _repo.forgotPassword(email));

  Future<bool> resetPassword({
    required String email,
    required String token,
    required String newPassword,
  }) =>
      _run(() => _repo.resetPassword(
            email: email,
            token: token,
            newPassword: newPassword,
          ));

  Future<bool> verifyEmail({
    required String email,
    required String token,
  }) =>
      _run(() => _repo.verifyEmail(email: email, token: token));

  Future<bool> sendVerifyEmail(String email) =>
      _run(() => _repo.sendVerifyEmail(email));

  Future<bool> logout() => _run(() => _repo.logout());

  /// Clears any error so a screen returning to its initial state hides the
  /// inline message (e.g. after a successful resend).
  void reset() => state = const AsyncValue<void>.data(null);
}

final authControllerProvider =
    AsyncNotifierProvider<AuthController, void>(AuthController.new);

/// Resolves the post-splash destination. Runs `restoreSession`; if a valid
/// session is restored → Home; otherwise → Onboarding on first run, else
/// → Sign in. Splash watches this and navigates once it resolves.
final splashRedirectProvider = FutureProvider<String>((ref) async {
  final repo = ref.read(authRepositoryProvider);
  final user = await repo.restoreSession();
  if (user != null) return Routes.home;
  final seen = await repo.hasSeenOnboarding();
  return seen ? Routes.signIn : Routes.onboarding;
});
