import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/auth_user.dart';
import '../network/dio_client.dart';

/// App-wide session state. The auth feature sets the user on login/restore and
/// clears it on logout; every other feature reads [currentUserProvider] /
/// [isAuthenticatedProvider]. Lives in core so features stay decoupled.
class SessionController extends Notifier<AuthUser?> {
  @override
  AuthUser? build() {
    // Preview seam: `--dart-define=PREVIEW_AUTHED=true` boots straight into the
    // authenticated app with a demo user. Off by default — never affects prod.
    if (const bool.fromEnvironment('PREVIEW_AUTHED')) {
      return const AuthUser(
        userId: 1,
        username: 'jane',
        fullName: 'Jane Smith',
        email: 'jane@example.com',
        phoneNumber: '07000 000000',
        role: 'customer',
      );
    }
    return null;
  }

  void setUser(AuthUser user) => state = user;
  void clear() => state = null;

  /// Client-side sign out: clears tokens + session. Callers that need the API
  /// logout call it first (auth feature); profile uses this directly.
  Future<void> signOut() async {
    await ref.read(dioClientProvider).clear();
    state = null;
  }
}

final sessionProvider =
    NotifierProvider<SessionController, AuthUser?>(SessionController.new);

final currentUserProvider = Provider<AuthUser?>((ref) => ref.watch(sessionProvider));

final isAuthenticatedProvider =
    Provider<bool>((ref) => ref.watch(sessionProvider) != null);
