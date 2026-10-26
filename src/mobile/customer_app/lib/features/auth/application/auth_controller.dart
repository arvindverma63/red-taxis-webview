import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/router/route_paths.dart';
import '../data/apple_sign_in_service.dart';
import '../data/auth_repository.dart';
import '../data/google_sign_in_service.dart';

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

  /// Signs in with Google. Returns false when the user cancels or it fails
  /// (an error, if any, is on the controller state).
  Future<bool> loginWithGoogle() async {
    final token = await GoogleSignInService().getIdToken().catchError((
      Object e,
    ) {
      state = AsyncValue<void>.error(
        e is ApiException ? e : const ApiException('Google sign-in failed.'),
        StackTrace.current,
      );
      return null;
    });
    if (token == null) return false;
    return _run(() => _repo.loginWithGoogle(token));
  }

  AppleAuthResult? _lastApple;

  /// Signs in with Apple. Returns false when the user cancels or it fails.
  Future<bool> loginWithApple() async {
    final result = await AppleSignInService().authorize().catchError((
      Object e,
    ) {
      state = AsyncValue<void>.error(
        e is ApiException ? e : const ApiException('Apple sign-in failed.'),
        StackTrace.current,
      );
      return null;
    });
    if (result == null) return false;
    _lastApple = result;
    return _sendApple(result);
  }

  /// True when the last Apple attempt failed only because no email was shared,
  /// so the screen can ask the customer for one and call [retryAppleWithEmail].
  bool get appleNeedsEmail {
    final e = state.error;
    return _lastApple != null &&
        e is ApiException &&
        e.message.toLowerCase().contains('email');
  }

  /// Re-sends the last Apple token with an email typed by the customer.
  Future<bool> retryAppleWithEmail(String email) {
    final last = _lastApple;
    if (last == null) return Future.value(false);
    return _sendApple(
      AppleAuthResult(
        identityToken: last.identityToken,
        fullName: last.fullName,
        email: email.trim(),
      ),
    );
  }

  Future<bool> _sendApple(AppleAuthResult r) => _run(
    () => _repo.loginWithApple(
      r.identityToken,
      fullName: r.fullName,
      email: r.email,
    ),
  );

  Future<bool> login({
    required String usernameOrEmail,
    required String password,
  }) => _run(
    () => _repo.login(usernameOrEmail: usernameOrEmail, password: password),
  );

  Future<bool> registerCustomer({
    required String fullName,
    required String email,
    required String phoneNumber,
    required String password,
  }) => _run(
    () => _repo.registerCustomer(
      fullName: fullName,
      email: email,
      phoneNumber: phoneNumber,
      password: password,
    ),
  );

  Future<bool> forgotPassword(String email) =>
      _run(() => _repo.forgotPassword(email));

  Future<bool> resetPassword({
    required String email,
    required String token,
    required String newPassword,
  }) => _run(
    () => _repo.resetPassword(
      email: email,
      token: token,
      newPassword: newPassword,
    ),
  );

  Future<bool> verifyEmail({required String email, required String token}) =>
      _run(() => _repo.verifyEmail(email: email, token: token));

  Future<bool> sendVerifyEmail(String email) =>
      _run(() => _repo.sendVerifyEmail(email));

  /// Deletes the account. Returns false (error on state) when it fails.
  /// Pass [password] for accounts that have one.
  Future<bool> deleteAccount({String? password}) =>
      _run(() => _repo.deleteAccount(password: password));

  /// True when the last delete attempt failed because a password is required
  /// (or was wrong), so the screen can ask for it and retry.
  bool get deleteNeedsPassword {
    final e = state.error;
    return e is ApiException && e.message.toLowerCase().contains('password');
  }

  Future<bool> logout() => _run(() => _repo.logout());

  /// Clears any error so a screen returning to its initial state hides the
  /// inline message (e.g. after a successful resend).
  void reset() => state = const AsyncValue<void>.data(null);
}

final authControllerProvider = AsyncNotifierProvider<AuthController, void>(
  AuthController.new,
);

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
