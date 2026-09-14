import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/activity_repository.dart';
import '../domain/booking_summary.dart';

/// Loads and holds the caller's bookings for the Activity tab. The list screen
/// watches [activityControllerProvider] for loading/error/data; the derived
/// [currentBookingsProvider] / [pastBookingsProvider] split it into the two
/// sections. Detail/amend/cancel actions live on the controller so a successful
/// change refreshes the list everywhere.
class ActivityController extends AsyncNotifier<List<BookingSummary>> {
  @override
  Future<List<BookingSummary>> build() {
    return ref.read(activityRepositoryProvider).myBookings();
  }

  ActivityRepository get _repo => ref.read(activityRepositoryProvider);

  /// Active (non-terminal) bookings, newest scheduled first — the "Current"
  /// section. Empty while loading/errored.
  List<BookingSummary> get current => state.valueOrNull
          ?.where((b) => b.isActive)
          .toList(growable: false) ??
      const [];

  /// Past + cancelled bookings — the "History" section.
  List<BookingSummary> get past => state.valueOrNull
          ?.where((b) => !b.isActive)
          .toList(growable: false) ??
      const [];

  /// Re-fetches the bookings, surfacing loading then data/error. Used by
  /// pull-to-refresh and after amend/cancel.
  Future<void> refresh() async {
    state = const AsyncValue<List<BookingSummary>>.loading();
    state = await AsyncValue.guard(_repo.myBookings);
  }

  /// Submits a change request, then refreshes so the list reflects any new
  /// state. Rethrows so the calling sheet can show an error.
  Future<void> requestChange(
    String id, {
    DateTime? newTime,
    int? passengers,
  }) async {
    await _repo.requestChange(id, newTime: newTime, passengers: passengers);
    await refresh();
  }

  /// Submits a cancellation, then refreshes. Rethrows on failure so the caller
  /// can surface it.
  Future<void> cancel(String id) async {
    await _repo.cancel(id);
    await refresh();
  }
}

final activityControllerProvider =
    AsyncNotifierProvider<ActivityController, List<BookingSummary>>(
  ActivityController.new,
);

/// Active bookings for the "Current" section. Rebuilds with the controller.
final currentBookingsProvider = Provider<List<BookingSummary>>((ref) {
  final bookings = ref.watch(activityControllerProvider).valueOrNull;
  return bookings?.where((b) => b.isActive).toList(growable: false) ??
      const [];
});

/// Past + cancelled bookings for the "History" section.
final pastBookingsProvider = Provider<List<BookingSummary>>((ref) {
  final bookings = ref.watch(activityControllerProvider).valueOrNull;
  return bookings?.where((b) => !b.isActive).toList(growable: false) ??
      const [];
});

// ── GoRide 4-tab view selectors ──────────────────────────────────────────────
// Pure, read-only derivations of the same controller data, split into the
// Ongoing / Scheduled / Completed / Canceled buckets the GoRide activity screen
// uses. No controller/repository logic changes — just a different slice of the
// same list, so all four tabs stay in sync with one fetch + refresh.

/// Live, in-flight trips — a driver is engaged, or it's a just-requested ASAP
/// ("Now") booking still awaiting allocation. The richer "Ongoing" card tab, so
/// a customer who just booked finds the trip here rather than under "Scheduled".
final ongoingBookingsProvider = Provider<List<BookingSummary>>((ref) {
  final bookings = ref.watch(activityControllerProvider).valueOrNull;
  return bookings?.where((b) => b.isOngoing).toList(growable: false) ??
      const [];
});

/// Genuinely future-dated, booked-ahead trips not yet driver-engaged — the
/// "Scheduled" tab. ASAP requests are excluded (they live under "Ongoing").
final scheduledBookingsProvider = Provider<List<BookingSummary>>((ref) {
  final bookings = ref.watch(activityControllerProvider).valueOrNull;
  return bookings?.where((b) => b.isAwaitingScheduled).toList(growable: false) ??
      const [];
});

/// Completed trips — the "Completed" tab.
final completedBookingsProvider = Provider<List<BookingSummary>>((ref) {
  final bookings = ref.watch(activityControllerProvider).valueOrNull;
  return bookings?.where((b) => b.isCompleted).toList(growable: false) ??
      const [];
});

/// Cancelled trips — the "Canceled" tab.
final canceledBookingsProvider = Provider<List<BookingSummary>>((ref) {
  final bookings = ref.watch(activityControllerProvider).valueOrNull;
  return bookings?.where((b) => b.isCancelled).toList(growable: false) ??
      const [];
});

/// Resolves a single booking for the detail screen — reads from the loaded list
/// where possible, otherwise asks the repository (which mocks/finds it).
final bookingDetailProvider =
    FutureProvider.family<BookingSummary, String>((ref, id) async {
  final loaded = ref.watch(activityControllerProvider).valueOrNull;
  if (loaded != null) {
    for (final b in loaded) {
      if (b.id == id) return b;
    }
  }
  return ref.read(activityRepositoryProvider).detail(id);
});
