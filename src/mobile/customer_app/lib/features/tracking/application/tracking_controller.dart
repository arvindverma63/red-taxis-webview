import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/tracking_repository.dart';
import '../domain/tracking_state.dart';

/// Live tracking stream for a given booking id.
///
/// Family keyed by `bookingId`. The screen watches this; the repository owns
/// the source (mock today, Pusher later — a one-method swap in the repo).
final trackingProvider =
    StreamProvider.family<TrackingState, String>((ref, bookingId) {
  return ref.watch(trackingRepositoryProvider).watch(bookingId);
});
