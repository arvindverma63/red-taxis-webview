import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/profile_repository.dart';
import '../domain/notification_item.dart';

/// Owns the notification inbox: load, mark read, clear all.
class NotificationsController extends AsyncNotifier<List<NotificationItem>> {
  ProfileRepository get _repo => ref.read(profileRepositoryProvider);

  @override
  Future<List<NotificationItem>> build() => _repo.notifications();

  Future<void> markRead(String id) async {
    final updated = await _repo.markRead(id);
    state = AsyncValue.data(updated);
  }

  Future<void> clearAll() async {
    final updated = await _repo.clearAll();
    state = AsyncValue.data(updated);
  }
}

final notificationsProvider =
    AsyncNotifierProvider<NotificationsController, List<NotificationItem>>(
  NotificationsController.new,
);

/// Convenience: unread count for the inbox badge.
final unreadNotificationsCountProvider = Provider<int>((ref) {
  final items = ref.watch(notificationsProvider).valueOrNull ?? const [];
  return items.where((n) => !n.read).length;
});
