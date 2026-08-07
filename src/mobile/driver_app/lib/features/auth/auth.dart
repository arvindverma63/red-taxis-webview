import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AuthStatus { authenticated, unauthenticated, authenticating }

class AuthState {
  final AuthStatus status;
  final String? email;
  final String? errorMessage;

  const AuthState({
    required this.status,
    this.email,
    this.errorMessage,
  });

  AuthState copyWith({
    AuthStatus? status,
    String? email,
    String? errorMessage,
  }) {
    return AuthState(
      status: status ?? this.status,
      email: email ?? this.email,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState(status: AuthStatus.unauthenticated));

  Future<void> signIn(String username, String password) async {
    state = state.copyWith(status: AuthStatus.authenticating);
    try {
      // TODO: Perform actual authentication with API
      await Future.delayed(const Duration(seconds: 1)); // Mock latency
      state = AuthState(status: AuthStatus.authenticated, email: username);
    } catch (e) {
      state = AuthState(
        status: AuthStatus.unauthenticated,
        errorMessage: e.toString(),
      );
    }
  }

  void signOut() {
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});
