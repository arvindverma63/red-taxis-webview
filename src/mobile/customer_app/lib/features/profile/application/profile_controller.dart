import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/auth_user.dart';
import '../data/profile_repository.dart';

/// Loads and edits the signed-in customer's profile. The repository keeps the
/// app-wide session in sync on update, so other features see edits immediately.
class ProfileController extends AsyncNotifier<AuthUser> {
  ProfileRepository get _repo => ref.read(profileRepositoryProvider);

  @override
  Future<AuthUser> build() => _repo.getProfile();

  /// Persist edited fields. Updates state on success; surfaces errors to the
  /// caller (the form maps them to a snackbar/inline message).
  Future<void> save({String? fullName, String? phoneNumber}) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => _repo.updateProfile(fullName: fullName, phoneNumber: phoneNumber),
    );
    // Re-throw on failure so the caller can keep the editor open.
    state.maybeWhen(
      error: (e, st) => Error.throwWithStackTrace(e, st),
      orElse: () {},
    );
  }
}

final profileControllerProvider =
    AsyncNotifierProvider<ProfileController, AuthUser>(ProfileController.new);
