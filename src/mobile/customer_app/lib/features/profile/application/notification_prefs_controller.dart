import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/profile_repository.dart';
import '../domain/notification_prefs.dart';

/// Owns the per-category push mute toggles. Each toggle persists immediately and
/// reflects in state.
class NotificationPrefsController extends AsyncNotifier<NotificationPrefs> {
  ProfileRepository get _repo => ref.read(profileRepositoryProvider);

  @override
  Future<NotificationPrefs> build() => _repo.prefs();

  Future<void> savePrefs(NotificationPrefs prefs) async {
    // Reflect instantly, then persist.
    state = AsyncValue.data(prefs);
    final saved = await _repo.savePrefs(prefs);
    state = AsyncValue.data(saved);
  }
}

final notificationPrefsProvider =
    AsyncNotifierProvider<NotificationPrefsController, NotificationPrefs>(
  NotificationPrefsController.new,
);
