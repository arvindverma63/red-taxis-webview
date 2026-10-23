import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../../core/logging/remote_logger.dart';
import '../../../core/network/api_exception.dart';

/// What Apple returns for a successful authorisation.
class AppleAuthResult {
  const AppleAuthResult({required this.identityToken, this.fullName});

  /// Signed JWT the backend verifies at `POST /api/v2/customer-auth/apple`.
  final String identityToken;

  /// Only provided by Apple the first time this Apple ID signs in to the app.
  final String? fullName;
}

/// Wraps Sign in with Apple and returns the identity token for the backend.
class AppleSignInService {
  /// Runs the Apple consent sheet. Returns null when the user cancels.
  /// Throws [ApiException] when Apple gives no identity token or sign-in fails.
  Future<AppleAuthResult?> authorize() async {
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );
      final token = credential.identityToken;
      if (token == null || token.isEmpty) {
        throw const ApiException(
          'Apple did not return a sign-in token. Please try again.',
        );
      }
      final name = [
        credential.givenName,
        credential.familyName,
      ].where((p) => p != null && p.trim().isNotEmpty).join(' ');
      return AppleAuthResult(
        identityToken: token,
        fullName: name.isEmpty ? null : name,
      );
    } on ApiException {
      rethrow;
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) return null;
      RemoteLogger.error('Apple', 'Sign-in failed: code=${e.code} ${e.message}');
      throw const ApiException(
        'Apple sign-in failed. Please try again or use your email.',
      );
    } catch (e) {
      RemoteLogger.error('Apple', 'Sign-in failed: $e');
      throw const ApiException(
        'Apple sign-in failed. Please try again or use your email.',
      );
    }
  }
}
