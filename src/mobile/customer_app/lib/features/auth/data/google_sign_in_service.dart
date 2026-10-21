import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/config/app_config.dart';
import '../../../core/logging/remote_logger.dart';
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
    } catch (e) {
      // Record the real reason (codes only, no account data) so a failure on a
      // device can be diagnosed from the log service, then show a clear message.
      final detail = e is PlatformException
          ? 'code=${e.code} message=${e.message}'
          : e.toString();
      RemoteLogger.error('Google', 'Sign-in failed: $detail');
      throw ApiException(_friendlyMessage(detail));
    }
  }

  /// Maps Google's error text to something a person can act on.
  static String _friendlyMessage(String detail) {
    final d = detail.toLowerCase();
    if (d.contains('apiexception: 10') || d.contains('developer_error')) {
      return "Google sign-in isn't set up correctly for this app build (error 10). Please use your email for now.";
    }
    if (d.contains('apiexception: 12500')) {
      return 'Google sign-in could not start (12500). Update Google Play services and try again.';
    }
    if (d.contains('apiexception: 12501') || d.contains('sign_in_canceled')) {
      return 'Google sign-in was cancelled.';
    }
    if (d.contains('network_error') || d.contains('apiexception: 7')) {
      return 'No connection. Check your internet and try again.';
    }
    return 'Google sign-in failed. Please try again or use your email.';
  }
}
