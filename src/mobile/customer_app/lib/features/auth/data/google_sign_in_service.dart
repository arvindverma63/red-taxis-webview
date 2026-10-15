import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_exception.dart';

/// Wraps the Google Sign-In SDK and returns the Google **ID token** that the
/// backend verifies at `POST /api/v2/customer-auth/google`.
class GoogleSignInService {
  GoogleSignInService()
    : _google = GoogleSignIn(
        scopes: const ['email', 'profile'],
        clientId: AppConfig.googleIosClientId.isEmpty
            ? null
            : AppConfig.googleIosClientId,
        serverClientId: AppConfig.googleServerClientId.isEmpty
            ? null
            : AppConfig.googleServerClientId,
      );

  final GoogleSignIn _google;

  /// Runs the Google consent flow. Returns null when the user cancels.
  /// Throws [ApiException] when Google gives no ID token.
  Future<String?> getIdToken() async {
    try {
      // Always show the account chooser so a previous account isn't reused.
      await _google.signOut();
      final account = await _google.signIn();
      if (account == null) return null;
      final auth = await account.authentication;
      final token = auth.idToken;
      if (token == null || token.isEmpty) {
        throw const ApiException(
          'Google did not return a sign-in token. Please try again.',
        );
      }
      return token;
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
        'Google sign-in failed. Please try again or use your email.',
      );
    }
  }
}
