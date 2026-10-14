import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/token_storage.dart';

/// Manages whether the first-time user guide has been seen or dismissed.
class UserGuideSeenController extends AsyncNotifier<bool> {
  static const _key = 'first_time_user_guide_seen';

  @override
  Future<bool> build() async {
    final storage = ref.watch(secureStorageProvider);
    try {
      final val = await storage.read(key: _key);
      return val == 'true';
    } catch (_) {
      return false;
    }
  }

  /// Marks the guide as seen so the home banner is dismissed.
  Future<void> markSeen() async {
    state = const AsyncValue.data(true);
    final storage = ref.read(secureStorageProvider);
    try {
      await storage.write(key: _key, value: 'true');
    } catch (_) {}
  }

  /// Resets the guide status (useful for reviewing or testing).
  Future<void> reset() async {
    state = const AsyncValue.data(false);
    final storage = ref.read(secureStorageProvider);
    try {
      await storage.delete(key: _key);
    } catch (_) {}
  }
}

/// Provider for checking if the first-time user guide has been completed or dismissed.
final userGuideSeenProvider =
    AsyncNotifierProvider<UserGuideSeenController, bool>(
  UserGuideSeenController.new,
);
